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
      <label htmlFor="manual-capture-text">捕捉当前意图</label>
      <textarea
        id="manual-capture-text"
        value={textContext}
        onChange={(event) => setTextContext(event.currentTarget.value)}
        placeholder="例如：整理竞品信息，晚点发给团队"
      />
      <button type="submit">捕捉</button>
    </form>
  );
}
