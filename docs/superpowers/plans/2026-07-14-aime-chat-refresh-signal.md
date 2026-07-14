# Aime Chat Refresh Signal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the desktop task panel shortly after the Aime bot posts a new message, while keeping Feishu Base as the only task source of truth.

**Architecture:** Add a read-only sync-script command that fetches the newest Aime conversation messages, remembers the latest message position in a local cursor file, and reports whether a new bot-authored message appeared. The native app checks that signal every 15 seconds and pulls Base only when it changes; the existing five-minute Base pull remains the recovery path.

**Tech Stack:** Node.js ESM, `lark-cli im +chat-messages-list`, Swift/AppKit timers, existing self-test and native packaging checks.

---

### Task 1: Incremental Aime message signal

**Files:**
- Modify: `scripts/aime-lark-sync.mjs`
- Modify: `config/aime-base.example.json`

- [x] Add failing self-test assertions for chat ID resolution, cursor comparison, first-run initialization, user-message filtering, and new bot-message detection.
- [x] Run `npm run lark:self-test` and verify it fails because the new helpers do not exist.
- [x] Implement `assistant-signal`: resolve the `oc_` ID from config, fetch the newest messages read-only, compare message positions, persist `tmp/aime-assistant-cursor.json`, and print `{changed, initialized}` JSON.
- [x] Run `npm run lark:self-test` and verify it passes.

### Task 2: Native 15-second watcher

**Files:**
- Modify: `native/AimeCompanion/main.swift`

- [x] Add a dedicated 15-second timer that invokes `assistant-signal` without changing the five-minute timer.
- [x] Parse the signal output and call the existing Base pull/reload path only for `changed: true`.
- [x] Invalidate both timers on quit and keep signal failures silent so offline use is not interrupted.
- [x] Run native compilation/package verification.

### Task 3: Documentation and verification

**Files:**
- Modify: `README.md`
- Modify: `package.json`

- [x] Document the Aime conversation signal, Base source-of-truth rule, and polling fallback.
- [x] Add a package command for a manual signal check.
- [x] Run self-test, frontend tests, lint, build, and native packaging.
- [x] Review the diff and commit the implementation.
