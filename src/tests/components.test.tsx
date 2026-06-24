import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { CollapsedWidget } from "../components/CollapsedWidget";
import { PeekPanel } from "../components/PeekPanel";
import { ProgressTrack } from "../components/ProgressTrack";
import type { ComputedProgressTrack, TaskViewModel } from "../domain/types";

const p0Task: TaskViewModel = {
  id: "p0",
  larkRecordId: "rec-p0",
  title: "P0・评审迭代方案",
  sourceType: "meeting_note",
  status: "open",
  dueDate: "2026-06-24",
  createdAt: "2026-06-24T00:00:00.000Z",
  updatedAt: "2026-06-24T00:00:00.000Z",
  project: "AI探索",
  meta: {
    taskId: "p0",
    pinned: true,
    hidden: false,
    displayPriority: 1,
  },
};

const tracks: ComputedProgressTrack[] = [
  {
    id: "walk",
    name: "遛狗 +1",
    linkedTaskIds: ["p0"],
    mode: "auto",
    autoPercent: 0,
    displayPercent: 0,
    completedTasks: 0,
    totalTasks: 1,
    pinned: true,
    updatedAt: "2026-06-24T00:00:00.000Z",
  },
];

describe("ProgressTrack", () => {
  it("shows manual override label", () => {
    render(
      <ProgressTrack
        track={{
          id: "track",
          name: "Aime Desktop MVP",
          linkedTaskIds: [],
          mode: "manual",
          manualPercent: 62,
          autoPercent: 0,
          displayPercent: 62,
          completedTasks: 0,
          totalTasks: 0,
          pinned: true,
          updatedAt: "2026-06-23T00:00:00.000Z",
        }}
      />,
    );

    expect(screen.getByText("Aime Desktop MVP")).toBeInTheDocument();
    expect(screen.getByText("62%")).toBeInTheDocument();
    expect(screen.getByText("manual override")).toBeInTheDocument();
  });
});

describe("Aime companion redesign", () => {
  it("shows the compact dog-food widget copy", () => {
    render(
      <CollapsedWidget
        overdueCount={2}
        todayCount={1}
        nextTask={p0Task}
        tracks={tracks}
        syncState="idle"
        onExpand={() => undefined}
        onOpenFull={() => undefined}
      />,
    );

    expect(screen.getByText("P0・1")).toBeInTheDocument();
    expect(screen.getByText("3 粒待领取狗粮")).toBeInTheDocument();
    expect(screen.getByText("🐶")).toBeInTheDocument();
    expect(document.querySelector(".dog-face")).not.toBeInTheDocument();
  });

  it("shows the reference expanded panel copy", () => {
    render(
      <PeekPanel
        overdueTasks={[p0Task]}
        todayTasks={[]}
        laterTasks={[]}
        tracks={tracks}
        onCollapse={() => undefined}
        onComplete={() => undefined}
        onTomorrow={() => undefined}
        onHide={() => undefined}
        onOpenFull={() => undefined}
      />,
    );

    expect(screen.getAllByText("下一件最重要的事")[0]).toBeInTheDocument();
    expect(screen.getByText("拖到飞书窗口：嗅探当前上下文")).toBeInTheDocument();
    expect(screen.getByText(/完成后遛狗 \+1/)).toBeInTheDocument();
    expect(screen.getByText("AI 试穿 - 迭代评测方案")).toBeInTheDocument();
  });
});
