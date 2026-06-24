import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { CollapsedWidget } from "../components/CollapsedWidget";
import { PeekPanel } from "../components/PeekPanel";
import { ProgressTrack } from "../components/ProgressTrack";
import { App } from "../App";
import type { AppSnapshot, ComputedProgressTrack, TaskViewModel } from "../domain/types";

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

const doneTask: TaskViewModel = {
  ...p0Task,
  id: "done-task",
  larkRecordId: "rec-done",
  title: "整理竞品信息",
  status: "done",
  meta: {
    taskId: "done-task",
    pinned: false,
    hidden: false,
    displayPriority: 0,
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
    const showTasks = vi.fn();

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
        onShowTasks={showTasks}
      />,
    );

    expect(screen.getAllByText("下一件最重要的事")[0]).toBeInTheDocument();
    expect(screen.getByText("手动捕捉当前意图")).toBeInTheDocument();
    expect(screen.getByText(/完成后遛狗 \+1/)).toBeInTheDocument();
    expect(screen.getAllByText("P0・评审迭代方案")[0]).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "展开待办，3 粒待领取狗粮" }));
    expect(showTasks).toHaveBeenCalled();
  });

  it("keeps completed tasks checked and at the bottom", () => {
    const reopenTask = vi.fn();

    render(
      <PeekPanel
        overdueTasks={[p0Task]}
        todayTasks={[]}
        laterTasks={[]}
        completedTasks={[doneTask]}
        tracks={tracks}
        onCollapse={() => undefined}
        onComplete={() => undefined}
        onReopen={reopenTask}
        onTomorrow={() => undefined}
        onHide={() => undefined}
        onOpenFull={() => undefined}
      />,
    );

    const rows = screen.getAllByRole("article");
    expect(rows[rows.length - 1]).toHaveTextContent("整理竞品信息");
    fireEvent.click(screen.getByLabelText("取消完成 整理竞品信息"));
    expect(reopenTask).toHaveBeenCalledWith("done-task");
  });

  it("reopens only the completed task the user clicked", async () => {
    const snapshot: AppSnapshot = {
      syncState: "idle",
      tasks: [
        {
          id: "open-task",
          larkRecordId: "rec-open",
          title: "继续推进方案",
          sourceType: "manual",
          status: "open",
          dueDate: "2026-06-24",
          createdAt: "2026-06-24T00:00:00.000Z",
          updatedAt: "2026-06-24T00:00:00.000Z",
        },
        {
          id: "done-one",
          larkRecordId: "rec-one",
          title: "已完成一",
          sourceType: "manual",
          status: "done",
          dueDate: "2026-06-24",
          createdAt: "2026-06-24T00:00:00.000Z",
          updatedAt: "2026-06-24T00:01:00.000Z",
        },
        {
          id: "done-two",
          larkRecordId: "rec-two",
          title: "已完成二",
          sourceType: "manual",
          status: "done",
          dueDate: "2026-06-24",
          createdAt: "2026-06-24T00:00:00.000Z",
          updatedAt: "2026-06-24T00:02:00.000Z",
        },
      ],
      localMeta: [
        { taskId: "open-task", pinned: false, hidden: false, displayPriority: 2 },
        { taskId: "done-one", pinned: false, hidden: false, displayPriority: 0 },
        { taskId: "done-two", pinned: false, hidden: false, displayPriority: 0 },
      ],
      tracks: [],
      settings: {
        widgetX: 0,
        widgetY: 0,
        miniMode: false,
        reminderHour: 9,
      },
    };
    window.localStorage.setItem("aime-desktop-task-companion.snapshot", JSON.stringify(snapshot));
    window.history.pushState(null, "", "/?mode=peek");

    render(<App />);

    fireEvent.click(await screen.findByLabelText("取消完成 已完成一"));

    await waitFor(() => {
      const saved = JSON.parse(
        window.localStorage.getItem("aime-desktop-task-companion.snapshot") ?? "{}",
      ) as AppSnapshot;
      expect(saved.tasks.find((task) => task.id === "done-one")?.status).toBe("open");
      expect(saved.tasks.find((task) => task.id === "done-two")?.status).toBe("done");
    });
    expect(await screen.findByLabelText("取消完成 已完成二")).toBeInTheDocument();
    expect(screen.getByLabelText("完成 已完成一")).toBeInTheDocument();
  });
});
