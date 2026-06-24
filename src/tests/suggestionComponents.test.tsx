import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ManualCaptureForm } from "../components/ManualCaptureForm";
import { SuggestionCard } from "../components/SuggestionCard";
import { SuggestionSettings } from "../components/SuggestionSettings";
import { defaultIntentSettings, type ProactiveSuggestion } from "../domain/intentTypes";

const suggestion: ProactiveSuggestion = {
  id: "suggestion-1",
  type: "create_task",
  title: "把这个意图沉淀成任务",
  body: "整理竞品信息",
  confidence: 0.72,
  sourceEventIds: ["evt-1"],
  relatedTaskIds: [],
  suggestedAction: {
    kind: "create_task",
    label: "创建任务",
    requiresConfirmation: true,
  },
  state: "pending",
  createdAt: "2026-06-24T09:00:00.000Z",
  expiresAt: "2026-06-24T11:00:00.000Z",
};

describe("SuggestionCard", () => {
  it("renders a compact suggestion and handles actions", async () => {
    const onAccept = vi.fn();
    const onDismiss = vi.fn();
    const onNeverSuggest = vi.fn();

    render(
      <SuggestionCard
        suggestion={suggestion}
        onAccept={onAccept}
        onDismiss={onDismiss}
        onNeverSuggest={onNeverSuggest}
      />,
    );

    expect(screen.getByText("把这个意图沉淀成任务")).toBeInTheDocument();
    expect(screen.getByText("整理竞品信息")).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "创建任务" }));
    fireEvent.click(screen.getByRole("button", { name: "忽略" }));
    fireEvent.click(screen.getByRole("button", { name: "不再建议这类" }));

    expect(onAccept).toHaveBeenCalledWith("suggestion-1");
    expect(onDismiss).toHaveBeenCalledWith("suggestion-1");
    expect(onNeverSuggest).toHaveBeenCalledWith("suggestion-1");
  });
});

describe("ManualCaptureForm", () => {
  it("captures text context only after explicit user submit", async () => {
    const onCapture = vi.fn();

    render(<ManualCaptureForm onCapture={onCapture} />);

    expect(screen.getByLabelText("交给 Aime 处理")).toBeInTheDocument();
    expect(
      screen.getByPlaceholderText("粘贴会议纪要、聊天记录，或直接告诉 Aime 要新增什么任务"),
    ).toBeInTheDocument();

    fireEvent.change(screen.getByLabelText("交给 Aime 处理"), {
      target: { value: "整理竞品信息" },
    });
    fireEvent.click(screen.getByRole("button", { name: "生成待确认任务" }));

    expect(onCapture).toHaveBeenCalledWith({
      triggerType: "manual_capture",
      textContext: "整理竞品信息",
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });
  });
});

describe("SuggestionSettings", () => {
  it("lets the user disable suggestions and clear local history", async () => {
    const onUpdateSettings = vi.fn();
    const onClearHistory = vi.fn();

    render(
      <SuggestionSettings
        settings={defaultIntentSettings}
        eventCount={3}
        suggestionCount={2}
        onUpdateSettings={onUpdateSettings}
        onClearHistory={onClearHistory}
      />,
    );

    fireEvent.click(screen.getByRole("checkbox", { name: "主动建议" }));
    fireEvent.click(screen.getByRole("button", { name: "清空本地意图历史" }));

    expect(onUpdateSettings).toHaveBeenCalledWith({ proactiveSuggestionsEnabled: false });
    expect(onClearHistory).toHaveBeenCalled();
  });
});
