import { useState } from "react";
import type { CaptureIntentEventInput } from "../domain/intentTypes";

interface ManualCaptureFormProps {
  onCapture: (input: CaptureIntentEventInput) => void;
}

export function ManualCaptureForm({ onCapture }: ManualCaptureFormProps) {
  const [textContext, setTextContext] = useState("");

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const trimmed = textContext.trim();
    if (!trimmed) return;

    onCapture({
      triggerType: "manual_capture",
      textContext: trimmed,
      relatedTaskIds: [],
      privacyLevel: "local_only",
    });
    setTextContext("");
  }

  return (
    <form className="manual-capture-form" onSubmit={handleSubmit}>
      <label htmlFor="manual-capture-text">交给飞书机器人处理</label>
      <textarea
        id="manual-capture-text"
        value={textContext}
        onChange={(event) => setTextContext(event.currentTarget.value)}
        placeholder="粘贴会议纪要、聊天记录，或直接告诉飞书机器人要新增什么任务"
      />
      <button type="submit">生成待确认任务</button>
    </form>
  );
}
