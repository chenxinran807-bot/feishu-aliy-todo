import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ProgressTrack } from "../components/ProgressTrack";

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
