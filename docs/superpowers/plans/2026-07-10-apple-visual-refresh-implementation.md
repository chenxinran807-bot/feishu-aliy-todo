# Apple Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify the widget, peek panel, full window, and native macOS shell around a restrained Apple-style visual system while replacing the fixed dog identity with a locally stored, user-uploadable circular avatar and initial fallback.

**Architecture:** Add a small, framework-independent profile domain module, expose profile persistence through the existing desktop API boundary, and render it through one `UserAvatar` component shared by all React surfaces. Keep the native shell's profile representation in the existing preferences store, using a local avatar file when available and the same initial fallback rules. Apply the visual refresh through semantic CSS tokens and existing component class names so task and Lark behavior remain unchanged.

**Tech Stack:** React 19, TypeScript, Vitest, Testing Library, CSS, Swift/AppKit, localStorage fallback, existing native JSON preferences.

---

## File map and ownership

- Create `src/domain/profile.ts`: profile types, supported-image validation, and deterministic initial fallback.
- Create `src/tests/profile.test.ts`: profile domain tests.
- Create `src/components/UserAvatar.tsx`: shared circular avatar rendering and file-selection boundary.
- Create `src/components/ProfileSettings.tsx`: full-window profile preview, nickname, replace, and reset controls.
- Create `src/tests/profileComponents.test.tsx`: avatar and settings component tests.
- Modify `src/domain/types.ts`: add `UserProfile` to `AppSnapshot`.
- Modify `src/data/sampleData.ts`: provide the default profile.
- Modify `src/lib/desktopApi.ts`: load, update, and reset profile in browser and native bridges.
- Modify `src/App.tsx`: own profile updates and pass profile to all three surfaces.
- Modify `src/components/CollapsedWidget.tsx`: replace `DogPortrait` with `UserAvatar`.
- Modify `src/components/PeekPanel.tsx`: add the compact avatar identity entry.
- Modify `src/components/FullWindow.tsx`: pass profile and profile actions into the sidebar tools.
- Modify `src/components/Sidebar.tsx`: render the profile identity block.
- Delete `src/components/DogPortrait.tsx` after all references are removed.
- Modify `src/styles.css`: semantic Apple-style tokens and consistent widget, panel, sidebar, avatar, task, focus, and responsive styling.
- Modify `src/tests/components.test.tsx`: update existing fixtures and assertions for `UserProfile`.
- Modify `native/AimeCompanion/AimeModels.swift`: replace dog defaults with profile fields and initial fallback.
- Modify `native/AimeCompanion/main.swift`: load a circular local avatar image or render the fallback initial.
- Modify `native/AimeCompanion/PetStateTests.swift`: replace dog-brand expectations with profile fallback tests.

> The worktree already contains unrelated user changes. Before every commit, inspect `git diff` and stage only the files or hunks named in that task. Never discard or rewrite unrelated changes.

### Task 1: Profile domain and snapshot contract

**Files:**
- Create: `src/domain/profile.ts`
- Create: `src/tests/profile.test.ts`
- Modify: `src/domain/types.ts`
- Modify: `src/data/sampleData.ts`
- Modify: `src/tests/components.test.tsx`

- [ ] **Step 1: Write failing profile-domain tests**

```ts
import { describe, expect, it } from "vitest";
import { getProfileInitial, isSupportedAvatarFile } from "../domain/profile";

describe("getProfileInitial", () => {
  it("uses the first Latin initial in uppercase", () => {
    expect(getProfileInitial("alice chen")).toBe("A");
  });

  it("uses the first Chinese nickname character", () => {
    expect(getProfileInitial("小兰")).toBe("小");
  });

  it("falls back to 神 for blank names", () => {
    expect(getProfileInitial("   ")).toBe("神");
  });
});

describe("isSupportedAvatarFile", () => {
  it.each(["image/png", "image/jpeg", "image/webp"])("accepts %s", (type) => {
    expect(isSupportedAvatarFile({ type })).toBe(true);
  });

  it("rejects unsupported image types", () => {
    expect(isSupportedAvatarFile({ type: "image/gif" })).toBe(false);
  });
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `npx vitest run src/tests/profile.test.ts`

Expected: FAIL because `src/domain/profile.ts` does not exist.

- [ ] **Step 3: Add the minimal profile types and helpers**

```ts
// src/domain/profile.ts
export interface UserProfile {
  displayName: string;
  avatarUrl?: string;
}

export const defaultUserProfile: UserProfile = { displayName: "神仙待办" };

export function getProfileInitial(displayName: string): string {
  const normalized = displayName.trim();
  if (!normalized) return "神";
  const first = Array.from(normalized)[0];
  return /[a-z]/i.test(first) ? first.toUpperCase() : first;
}

export function isSupportedAvatarFile(file: Pick<File, "type">): boolean {
  return ["image/png", "image/jpeg", "image/webp"].includes(file.type);
}
```

Add `profile: UserProfile` to `AppSnapshot`, import the type from `profile.ts`, add `profile: defaultUserProfile` to `sampleSnapshot`, and update every literal `AppSnapshot` fixture in `src/tests/components.test.tsx`.

- [ ] **Step 4: Run focused and type tests and verify GREEN**

Run: `npx vitest run src/tests/profile.test.ts src/tests/components.test.tsx && npm run lint`

Expected: all selected tests pass and TypeScript exits 0.

- [ ] **Step 5: Commit only Task 1 files**

```bash
git add src/domain/profile.ts src/tests/profile.test.ts src/domain/types.ts src/data/sampleData.ts
git add -p src/tests/components.test.tsx
git commit -m "feat: add local user profile model"
```

### Task 2: Profile persistence through the desktop API

**Files:**
- Modify: `src/lib/desktopApi.ts`
- Create: `src/tests/profileApi.test.ts`

- [ ] **Step 1: Write failing API persistence tests**

```ts
import { beforeEach, describe, expect, it } from "vitest";
import { desktopApi } from "../lib/desktopApi";

describe("profile desktop API", () => {
  beforeEach(() => window.localStorage.clear());

  it("persists profile changes in the snapshot", async () => {
    const snapshot = await desktopApi.updateProfile({ displayName: "小兰", avatarUrl: "data:image/png;base64,abc" });
    expect(snapshot.profile).toEqual({ displayName: "小兰", avatarUrl: "data:image/png;base64,abc" });
    expect((await desktopApi.getSnapshot()).profile.displayName).toBe("小兰");
  });

  it("resets only the avatar", async () => {
    await desktopApi.updateProfile({ displayName: "Alice", avatarUrl: "data:image/png;base64,abc" });
    expect((await desktopApi.resetAvatar()).profile).toEqual({ displayName: "Alice" });
  });
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `npx vitest run src/tests/profileApi.test.ts`

Expected: FAIL because `updateProfile` and `resetAvatar` are missing.

- [ ] **Step 3: Add API methods and legacy snapshot normalization**

Extend `AimeDesktopApi`:

```ts
updateProfile: (profile: UserProfile) => Promise<AppSnapshot>;
resetAvatar: () => Promise<AppSnapshot>;
```

Normalize old snapshots on read:

```ts
function normalizeSnapshot(snapshot: AppSnapshot): AppSnapshot {
  return { ...snapshot, profile: snapshot.profile ?? defaultUserProfile };
}
```

Implement browser methods by updating `snapshot.profile` and saving the snapshot. When a native bridge exists, post `{ command: "updateProfile", profile }` or `{ command: "resetAvatar" }`; `avatarUrl` is a Data URL at this boundary so AppKit can decode and copy it into the application data directory. Browser-only preview mode retains the Data URL in localStorage.

- [ ] **Step 4: Run the focused tests and verify GREEN**

Run: `npx vitest run src/tests/profileApi.test.ts src/tests/intentApi.test.ts`

Expected: all selected tests pass.

- [ ] **Step 5: Commit only Task 2 files**

```bash
git add src/lib/desktopApi.ts src/tests/profileApi.test.ts
git commit -m "feat: persist local avatar profile"
```

### Task 3: Shared circular avatar and settings controls

**Files:**
- Create: `src/components/UserAvatar.tsx`
- Create: `src/components/ProfileSettings.tsx`
- Create: `src/tests/profileComponents.test.tsx`
- Delete: `src/components/DogPortrait.tsx`

- [ ] **Step 1: Write failing rendering and upload tests**

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ProfileSettings } from "../components/ProfileSettings";
import { UserAvatar } from "../components/UserAvatar";

it("renders an initial when no avatar exists", () => {
  render(<UserAvatar profile={{ displayName: "小兰" }} size="compact" />);
  expect(screen.getByText("小")).toBeInTheDocument();
});

it("renders a circular centered image", () => {
  render(<UserAvatar profile={{ displayName: "Alice", avatarUrl: "avatar.png" }} size="hero" />);
  expect(screen.getByRole("img", { name: "Alice 的头像" })).toHaveClass("user-avatar__image");
});

it("rejects unsupported files without replacing the profile", () => {
  const onChange = vi.fn();
  render(<ProfileSettings profile={{ displayName: "Alice" }} onChange={onChange} onResetAvatar={vi.fn()} />);
  fireEvent.change(screen.getByLabelText("选择头像图片"), {
    target: { files: [new File(["gif"], "avatar.gif", { type: "image/gif" })] },
  });
  expect(onChange).not.toHaveBeenCalled();
  expect(screen.getByRole("alert")).toHaveTextContent("请选择 PNG、JPEG 或 WebP 图片");
});
```

- [ ] **Step 2: Run focused component tests and verify RED**

Run: `npx vitest run src/tests/profileComponents.test.tsx`

Expected: FAIL because both components are missing.

- [ ] **Step 3: Implement minimal components**

`UserAvatar` renders either an `<img>` or `getProfileInitial(profile.displayName)` inside one `.user-avatar` container. `ProfileSettings` uses `<input type="file" accept="image/png,image/jpeg,image/webp">`, validates MIME type, reads accepted files with `FileReader.readAsDataURL`, displays a circular preview, and calls `onChange({ ...profile, avatarUrl: result })` only after a successful read. It exposes a nickname input and a “恢复首字头像” button.

- [ ] **Step 4: Add explicit image-load fallback test and implementation**

```tsx
it("falls back to the initial when the avatar image fails", () => {
  render(<UserAvatar profile={{ displayName: "Alice", avatarUrl: "missing.png" }} size="compact" />);
  fireEvent.error(screen.getByRole("img"));
  expect(screen.getByText("A")).toBeInTheDocument();
});
```

Store an internal `imageFailed` boolean in `UserAvatar` and reset it when `avatarUrl` changes.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `npx vitest run src/tests/profileComponents.test.tsx && npm run lint`

Expected: tests pass and TypeScript exits 0.

- [ ] **Step 6: Delete the obsolete dog component after confirming no imports remain**

Run: `rg -n "DogPortrait|dog-portrait|dog-emoji" src`

Expected before deletion: only the old component and current imports; after Task 4 integration, zero results. Defer physical deletion until Task 4 if imports still exist.

- [ ] **Step 7: Commit created component files**

```bash
git add src/components/UserAvatar.tsx src/components/ProfileSettings.tsx src/tests/profileComponents.test.tsx
git commit -m "feat: add customizable circular avatar"
```

### Task 4: Integrate the profile across all React surfaces

**Files:**
- Modify: `src/App.tsx`
- Modify: `src/components/CollapsedWidget.tsx`
- Modify: `src/components/PeekPanel.tsx`
- Modify: `src/components/FullWindow.tsx`
- Modify: `src/components/Sidebar.tsx`
- Modify: `src/tests/components.test.tsx`
- Delete: `src/components/DogPortrait.tsx`

- [ ] **Step 1: Write failing integration assertions**

Add tests that render each surface with `profile={{ displayName: "小兰" }}` and assert that the same “小” avatar is visible. For `FullWindow`, also assert buttons named “更换头像” and “恢复首字头像” are reachable in the sidebar tools.

- [ ] **Step 2: Run component tests and verify RED**

Run: `npx vitest run src/tests/components.test.tsx src/tests/profileComponents.test.tsx`

Expected: FAIL because surface props and profile controls are not wired.

- [ ] **Step 3: Wire profile state and actions through App**

Add:

```ts
async function updateProfile(profile: UserProfile) {
  setSnapshot(await desktopApi.updateProfile(profile));
}

async function resetAvatar() {
  setSnapshot(await desktopApi.resetAvatar());
}
```

Pass `snapshot.profile` to `CollapsedWidget`, `PeekPanel`, and `FullWindow`. Pass update/reset handlers to `FullWindow` and use `UserAvatar` in the widget, peek header, and sidebar profile block.

- [ ] **Step 4: Remove all dog UI references**

Delete `DogPortrait.tsx`, its imports, its CSS selectors, dog emoji strings, and pet-specific accessible labels in React code.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `npx vitest run src/tests/components.test.tsx src/tests/profileComponents.test.tsx src/tests/profileApi.test.ts`

Expected: all selected tests pass.

- [ ] **Step 6: Commit only Task 4 hunks**

```bash
git add src/App.tsx src/components/CollapsedWidget.tsx src/components/PeekPanel.tsx src/components/FullWindow.tsx src/components/Sidebar.tsx src/components/DogPortrait.tsx
git add -p src/tests/components.test.tsx
git commit -m "feat: use profile avatar across desktop surfaces"
```

### Task 5: Apple-style visual token and component refresh

**Files:**
- Modify: `src/styles.css`
- Modify: `src/tests/profileComponents.test.tsx`

- [ ] **Step 1: Add failing structural style assertions**

Use DOM-level assertions for semantic classes rather than brittle computed pixel values:

```tsx
expect(screen.getByRole("img", { name: "Alice 的头像" }).parentElement).toHaveClass(
  "user-avatar",
  "user-avatar--hero",
);
expect(screen.getByRole("complementary")).toHaveClass("sidebar", "sidebar--frosted");
```

- [ ] **Step 2: Run the test and verify RED**

Run: `npx vitest run src/tests/profileComponents.test.tsx src/tests/components.test.tsx`

Expected: FAIL because the final semantic classes are absent.

- [ ] **Step 3: Consolidate semantic tokens and refresh components**

At the top of `styles.css`, define one token set:

```css
:root {
  --surface-canvas: #ffffff;
  --surface-muted: #f5f5f7;
  --surface-frosted: rgba(246, 246, 248, 0.82);
  --ink-primary: #1d1d1f;
  --ink-secondary: #6e6e73;
  --ink-tertiary: #8e8e93;
  --action-primary: #0071e3;
  --action-primary-pressed: #0066cc;
  --semantic-danger: #ff3b30;
  --hairline: rgba(60, 60, 67, 0.12);
  --radius-control: 10px;
  --radius-card: 18px;
  --radius-floating: 24px;
  --shadow-floating: 0 18px 45px rgba(0, 0, 0, 0.14);
}
```

Map existing aliases to these tokens while migrating selectors. Apply `backdrop-filter: saturate(180%) blur(20px)` only to floating shells and `.sidebar--frosted`. Give all buttons and inputs a visible `:focus-visible` outline, keep primary hit targets at 44px, and style `.user-avatar__image` with `width/height: 100%`, `border-radius: 50%`, `object-fit: cover`, and `object-position: center`.

- [ ] **Step 4: Run tests and type checking and verify GREEN**

Run: `npx vitest run src/tests/components.test.tsx src/tests/profileComponents.test.tsx && npm run lint`

Expected: all selected tests pass and TypeScript exits 0.

- [ ] **Step 5: Commit only CSS and related test hunks**

```bash
git add src/styles.css
git add -p src/tests/profileComponents.test.tsx src/tests/components.test.tsx
git commit -m "style: unify Apple-inspired desktop surfaces"
```

### Task 6: Native macOS profile fallback and dog removal

**Files:**
- Modify: `native/AimeCompanion/AimeModels.swift`
- Modify: `native/AimeCompanion/main.swift`
- Modify: `native/AimeCompanion/PetStateTests.swift`

- [ ] **Step 1: Replace dog-default tests with failing profile tests**

```swift
let profile = UserProfile(displayName: "alice chen", avatarPath: nil)
assertEqual(profile.fallbackInitial, "A", "Latin profile initials should uppercase")

let chineseProfile = UserProfile(displayName: "小兰", avatarPath: nil)
assertEqual(chineseProfile.fallbackInitial, "小", "Chinese profile initials should keep the first character")

let blankProfile = UserProfile(displayName: "   ", avatarPath: nil)
assertEqual(blankProfile.fallbackInitial, "神", "Blank profile names should fall back to 神")
```

Remove expectations that the default brand icon is `🐶`.

- [ ] **Step 2: Run native tests and verify RED**

Run: `npm run native:test`

Expected: Swift compilation FAIL because `UserProfile` is missing.

- [ ] **Step 3: Add native profile model and persistence compatibility**

Add a Codable `UserProfile` with `displayName`, optional `avatarPath`, and computed `fallbackInitial`. Decode absent profile values using `UserProfile(displayName: "神仙待办", avatarPath: nil)` so existing preferences remain valid. Handle the native `updateProfile` command by decoding the Data URL, validating PNG/JPEG/WebP signatures, writing the bytes to `<Application Support>/神仙待办/profile/avatar.<ext>`, and storing that path. Handle `resetAvatar` by clearing `avatarPath` and removing only the managed avatar file.

- [ ] **Step 4: Render image or initial in AppKit**

Add a helper that returns an `NSImageView` when `avatarPath` resolves to an image; otherwise return the existing label view with `fallbackInitial`. Set the image view to scale proportionally up or down, enable layer masking, and set `cornerRadius = size / 2`. Replace `dogFace()` branches and remove dog emoji states from widget and panel rendering.

- [ ] **Step 5: Run native tests and verify GREEN**

Run: `npm run native:test`

Expected: native profile tests and all existing state tests pass.

- [ ] **Step 6: Commit only native profile changes**

```bash
git add native/AimeCompanion/AimeModels.swift native/AimeCompanion/main.swift native/AimeCompanion/PetStateTests.swift
git commit -m "feat: replace native pet icon with user profile"
```

### Task 7: Full regression, production build, and visual inspection

**Files:**
- Modify only if verification exposes an in-scope defect.

- [ ] **Step 1: Verify no fixed dog identity remains**

Run: `rg -n "🐶|DogPortrait|dog-portrait|dogFace\(|小狗" src native`

Expected: zero results, except historical task content if deliberately retained as user data. Any UI or default-brand result must be removed.

- [ ] **Step 2: Run the complete automated suite**

Run: `npm test`

Expected: all Vitest and native Swift tests pass with zero failures.

- [ ] **Step 3: Run type checking and production build**

Run: `npm run lint && npm run build`

Expected: TypeScript and Vite/native builds exit 0.

- [ ] **Step 4: Package the app**

Run: `npm run native:package`

Expected: `.build/神仙待办.app` is produced successfully.

- [ ] **Step 5: Inspect the three modes visually**

Run the app and check:

- Widget: circular centered avatar, task count, next task, sync state, restrained floating shadow.
- Peek: same avatar, correct task hierarchy, no clipped content, visible keyboard focus.
- Full window: frosted light sidebar, white canvas, profile settings, circular preview, consistent control radii.
- Upload PNG, JPEG, and WebP; confirm immediate cross-surface refresh.
- Delete the avatar; confirm the same initial appears everywhere.
- Temporarily make the avatar path invalid; confirm fallback without breaking task UI.

- [ ] **Step 6: Inspect the final diff for user-change safety**

Run: `git status -sb && git diff --check && git diff --stat`

Expected: no whitespace errors; unrelated pre-existing work remains intact.

- [ ] **Step 7: Commit verification-only fixes if any**

Stage only files changed to correct an in-scope verification defect, then commit:

```bash
git commit -m "fix: polish avatar and Apple visual refresh"
```

Skip this commit when verification required no additional edits.
