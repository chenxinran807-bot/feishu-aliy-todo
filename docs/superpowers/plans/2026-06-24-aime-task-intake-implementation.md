# Aime Task Intake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Aime receive meeting notes, chat records, or direct user instructions, extract pending tasks, show them for confirmation, and only add them to the local task list after the user accepts.

**Architecture:** Add a small deterministic task extraction module used by the intent suggestion pipeline. Keep all generated tasks as pending `create_task` suggestions first; accepting a suggestion continues to use the existing local task creation path. This preserves the product boundary that Aime can summarize and propose tasks, but users decide what becomes a task.

**Tech Stack:** React, TypeScript, Vitest, localStorage-backed desktop API fallback.

---

### Task 1: Extract Tasks From User-Provided Material

**Files:**
- Create: `src/domain/taskIntake.ts`
- Test: `src/tests/taskIntake.test.ts`

- [ ] **Step 1: Write the failing test**

Create `src/tests/taskIntake.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { extractTaskDraftsFromMaterial } from "../domain/taskIntake";

describe("task intake", () => {
  it("extracts action items from meeting notes and chat records", () => {
    expect(
      extractTaskDraftsFromMaterial(
        "会议纪要：1. 周三前整理竞品信息；2. 明天发评审材料给团队；聊天记录：记得跟进设计反馈。",
      ),
    ).toEqual([
      { title: "周三前整理竞品信息", sourceType: "meeting_note" },
      { title: "明天发评审材料给团队", sourceType: "meeting_note" },
      { title: "跟进设计反馈", sourceType: "group_chat" },
    ]);
  });

  it("treats a direct instruction as one manual task", () => {
    expect(extractTaskDraftsFromMaterial("帮我新增任务：整理明天的 demo checklist")).toEqual([
      { title: "整理明天的 demo checklist", sourceType: "manual" },
    ]);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- src/tests/taskIntake.test.ts`

Expected: FAIL because `src/domain/taskIntake.ts` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `src/domain/taskIntake.ts`:

```ts
import type { SourceType } from "./types";

export interface TaskDraft {
  title: string;
  sourceType: SourceType;
}

export function extractTaskDraftsFromMaterial(material: string): TaskDraft[] {
  const normalized = material.trim();
  if (!normalized) return [];

  const direct = normalized.match(/(?:帮我新增任务|新增任务|创建任务)[:：]?\s*(.+)$/);
  if (direct?.[1]) {
    return [{ title: cleanTitle(direct[1]), sourceType: "manual" }].filter((draft) => draft.title);
  }

  const sourceType = inferSourceType(normalized);
  const candidates = normalized
    .split(/(?:\d+[.、]\s*|；|;|\n|聊天记录[:：]|会议纪要[:：])/)
    .map(cleanTitle)
    .filter(Boolean)
    .filter(isTaskLike);

  return Array.from(new Set(candidates)).map((title) => ({
    title,
    sourceType: title.includes("跟进") ? "group_chat" : sourceType,
  }));
}

function inferSourceType(value: string): SourceType {
  if (value.includes("聊天记录")) return "group_chat";
  if (value.includes("会议纪要") || value.includes("会议")) return "meeting_note";
  return "manual";
}

function cleanTitle(value: string): string {
  return value
    .replace(/^(记得|需要|请|待办|任务)[:：]?\s*/u, "")
    .replace(/[。.!！]+$/u, "")
    .trim();
}

function isTaskLike(value: string): boolean {
  return /整理|发送|发|跟进|确认|同步|补充|更新|创建|新增|评审|checklist/i.test(value);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- src/tests/taskIntake.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/domain/taskIntake.ts src/tests/taskIntake.test.ts
git commit -m "feat: extract Aime task drafts from material"
```

### Task 2: Turn Extracted Drafts Into Pending Suggestions

**Files:**
- Modify: `src/domain/suggestionRules.ts`
- Test: `src/tests/suggestionRules.test.ts`

- [ ] **Step 1: Write the failing test**

Add to `src/tests/suggestionRules.test.ts`:

```ts
it("creates one pending task suggestion for each extracted material task", () => {
  const suggestions = generateSuggestions({
    events: [
      {
        id: "evt-material",
        triggerType: "manual_capture",
        textContext: "会议纪要：1. 周三前整理竞品信息；2. 明天发评审材料给团队",
        relatedTaskIds: [],
        createdAt: "2026-06-24T09:00:00.000Z",
        privacyLevel: "local_only",
      },
    ],
    sessions: [],
    existingSuggestions: [],
    settings: defaultIntentSettings,
    now: "2026-06-24T09:00:00.000Z",
  });

  expect(suggestions.map((suggestion) => suggestion.body)).toEqual([
    "周三前整理竞品信息",
    "明天发评审材料给团队",
  ]);
  expect(suggestions.every((suggestion) => suggestion.suggestedAction.requiresConfirmation)).toBe(true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- src/tests/suggestionRules.test.ts`

Expected: FAIL because `generateSuggestions` currently only uses grouped sessions.

- [ ] **Step 3: Write minimal implementation**

In `src/domain/suggestionRules.ts`, import `extractTaskDraftsFromMaterial`, scan manual capture events with no related task ids, and create one `create_task` suggestion per extracted draft. Use stable ids like `suggestion-${event.id}-${index}` and skip ids already present in `existingSuggestions`.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- src/tests/suggestionRules.test.ts`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/domain/suggestionRules.ts src/tests/suggestionRules.test.ts
git commit -m "feat: suggest tasks from Aime material intake"
```

### Task 3: Make The Input UI Match The New Source Model

**Files:**
- Modify: `src/components/ManualCaptureForm.tsx`
- Modify: `src/tests/suggestionComponents.test.tsx`

- [ ] **Step 1: Write the failing test**

Update the ManualCaptureForm test to expect:

```ts
expect(screen.getByLabelText("交给 Aime 处理")).toBeInTheDocument();
expect(screen.getByPlaceholderText("粘贴会议纪要、聊天记录，或直接告诉 Aime 要新增什么任务")).toBeInTheDocument();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm test -- src/tests/suggestionComponents.test.tsx`

Expected: FAIL because the UI still says "捕捉当前意图".

- [ ] **Step 3: Write minimal implementation**

Change the label to `交给 Aime 处理`, placeholder to `粘贴会议纪要、聊天记录，或直接告诉 Aime 要新增什么任务`, and button text to `生成待确认任务`.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm test -- src/tests/suggestionComponents.test.tsx`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/components/ManualCaptureForm.tsx src/tests/suggestionComponents.test.tsx
git commit -m "feat: rename Aime material intake UI"
```

### Task 4: Full Verification

**Files:**
- No source files.

- [ ] **Step 1: Run typecheck**

Run: `npm run lint`

Expected: exit 0.

- [ ] **Step 2: Run full tests**

Run: `npm test`

Expected: all tests pass.

- [ ] **Step 3: Run production build**

Run: `npm run build`

Expected: build exits 0.

- [ ] **Step 4: Commit plan progress if needed**

```bash
git status -sb
```

Expected: clean working tree after task commits.
