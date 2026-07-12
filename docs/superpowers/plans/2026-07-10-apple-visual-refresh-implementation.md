# macOS × 飞书轻量面板实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a resizable, size-persistent macOS-style floating task panel using Feishu visual semantics and no avatar, product-brand, dog, or desktop-pet content.

**Architecture:** Extend existing companion settings with window dimensions, keep layout behavior in a pure size-policy module, and route resize preset commands through the existing desktop API/native message bridge. Apply semantic Feishu tokens to existing React surfaces and remove pet identity from both React and AppKit without changing task synchronization.

**Tech Stack:** React 19, TypeScript, Vitest, CSS, Swift/AppKit.

---

### Task 1: Window size policy

**Files:**
- Create: `src/domain/windowSizing.ts`
- Create: `src/tests/windowSizing.test.ts`
- Modify: `src/domain/types.ts`
- Modify: `src/data/sampleData.ts`

- [ ] Write failing tests for clamping, presets, and compact/standard/large density.
- [ ] Run `npx vitest run src/tests/windowSizing.test.ts` and confirm RED.
- [ ] Implement constants `320×220`, `360×260`, `480×420`, max `560×520`, `clampWindowSize`, and `getPanelDensity`.
- [ ] Add `widgetWidth` and `widgetHeight` to `CompanionSettings` with standard defaults.
- [ ] Run focused tests and `npm run lint`.

### Task 2: Resize API and responsive React panel

**Files:**
- Modify: `src/lib/desktopApi.ts`
- Modify: `src/App.tsx`
- Modify: `src/components/CollapsedWidget.tsx`
- Modify: `src/components/PeekPanel.tsx`
- Modify: `src/tests/components.test.tsx`

- [ ] Write failing tests for preset selection and density-based visibility.
- [ ] Run focused tests and confirm RED.
- [ ] Add `setWindowSize(width, height)` to the desktop API and native bridge.
- [ ] Render only summary plus 3 tasks in compact mode; reveal more content by density.
- [ ] Add accessible small/standard/large preset actions in the expanded panel.
- [ ] Run focused tests and `npm run lint`.

### Task 3: macOS × 飞书 visual system and identity removal

**Files:**
- Modify: `src/components/CollapsedWidget.tsx`
- Modify: `src/components/PeekPanel.tsx`
- Modify: `src/components/FullWindow.tsx`
- Modify: `src/components/Sidebar.tsx`
- Delete: `src/components/DogPortrait.tsx`
- Modify: `src/styles.css`
- Modify: `src/tests/components.test.tsx`

- [ ] Write failing assertions that no dog/avatar/brand region is rendered and that resize controls remain accessible.
- [ ] Run focused tests and confirm RED.
- [ ] Remove `DogPortrait`, identity markup, reward/pet wording, and permanent sidebar from the compact surface.
- [ ] Introduce semantic tokens `#3370FF`, `#F54A45`, `#1F2329`, `#646A73`, and `#F5F6F7` with macOS system typography, radius, blur, shadow, and focus treatment.
- [ ] Add small/standard/large responsive rules without shrinking text below readable sizes.
- [ ] Run focused tests and `npm run lint`.

### Task 4: Native AppKit resizing and pet removal

**Files:**
- Modify: `native/AimeCompanion/AimeModels.swift`
- Modify: `native/AimeCompanion/main.swift`
- Modify: `native/AimeCompanion/PetStateTests.swift`

- [ ] Write failing Swift tests for size defaults, clamping, and absence of dog brand defaults.
- [ ] Run `npm run native:test` and confirm RED.
- [ ] Persist width/height alongside position, set `contentMinSize`/`contentMaxSize`, enable resize, and handle `setWindowSize` presets.
- [ ] Remove dog emoji, dog mood presentation, cute display paths, and pet/reward UI copy while preserving task-state calculations needed by synchronization.
- [ ] Run `npm run native:test`.

### Task 5: Full verification

- [ ] Run `rg -n "🐶|DogPortrait|dog-portrait|dogFace\(|桌宠|小狗|宠物|头像" src native` and remove remaining UI/default identity results.
- [ ] Run `npm test`.
- [ ] Run `npm run lint && npm run build`.
- [ ] Package with `npm run native:package`.
- [ ] Inspect small, standard, large, and freely resized states; verify size/position restoration after restart.
- [ ] Run `git diff --check` and inspect that unrelated pre-existing changes remain intact.
