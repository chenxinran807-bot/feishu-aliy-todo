import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { CollapsedWidget } from "../components/CollapsedWidget";
import { FullWindow } from "../components/FullWindow";
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
    fireEvent.click(screen.getByRole("button", { name: "展开全部待办，1 粒待领取狗粮" }));
    expect(showTasks).toHaveBeenCalled();
  });

  it("lets each visible stat jump to its task group", () => {
    const overdueTask: TaskViewModel = {
      ...p0Task,
      id: "overdue",
      title: "逾期材料整理",
      dueDate: "2026-06-23",
      meta: { ...p0Task.meta, taskId: "overdue", displayPriority: 2 },
    };
    const laterTask: TaskViewModel = {
      ...p0Task,
      id: "later",
      title: "普通待办",
      dueDate: "2026-06-26",
      meta: { ...p0Task.meta, taskId: "later", displayPriority: 0 },
    };

    render(
      <PeekPanel
        overdueTasks={[overdueTask]}
        todayTasks={[p0Task]}
        laterTasks={[laterTask]}
        tracks={tracks}
        onCollapse={() => undefined}
        onComplete={() => undefined}
        onTomorrow={() => undefined}
        onHide={() => undefined}
        onOpenFull={() => undefined}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: "展开 P0 待办，1 件" }));
    expect(screen.getByLabelText("待办事项")).toHaveTextContent("P0・评审迭代方案");
    expect(screen.getByLabelText("待办事项")).not.toHaveTextContent("逾期材料整理");

    fireEvent.click(screen.getByRole("button", { name: "展开逾期待办，1 件" }));
    expect(screen.getByLabelText("待办事项")).toHaveTextContent("逾期材料整理");
    expect(screen.getByLabelText("待办事项")).not.toHaveTextContent("普通待办");

    fireEvent.click(screen.getByRole("button", { name: "展开全部待办，3 粒待领取狗粮" }));
    expect(screen.getByLabelText("待办事项")).toHaveTextContent("普通待办");
  });

  it("hides empty P0 and overdue stat cards", () => {
    const normalTask: TaskViewModel = {
      ...p0Task,
      id: "normal",
      title: "普通待办",
      meta: { ...p0Task.meta, taskId: "normal", displayPriority: 0 },
    };

    render(
      <PeekPanel
        overdueTasks={[]}
        todayTasks={[normalTask]}
        laterTasks={[]}
        tracks={tracks}
        onCollapse={() => undefined}
        onComplete={() => undefined}
        onTomorrow={() => undefined}
        onHide={() => undefined}
        onOpenFull={() => undefined}
      />,
    );

    expect(screen.queryByText("P0")).not.toBeInTheDocument();
    expect(screen.queryByText("逾期")).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "展开全部待办，1 粒待领取狗粮" })).toBeInTheDocument();
  });

  it("uses the checkbox as the only task completion control", () => {
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

    expect(screen.getByLabelText("完成 P0・评审迭代方案")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "完成" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "改时间" })).not.toBeInTheDocument();
  });

  it("does not show placeholder completion or reschedule actions in the full window", () => {
    render(
      <FullWindow
        snapshot={{
          syncState: "idle",
          tasks: [p0Task],
          localMeta: [],
          tracks: [],
          settings: {
            widgetX: 0,
            widgetY: 0,
            miniMode: false,
            reminderHour: 9,
          },
        }}
        tracks={tracks}
      />,
    );

    expect(screen.queryByText("完成")).not.toBeInTheDocument();
    expect(screen.queryByText("改时间")).not.toBeInTheDocument();
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
