import { describe, expect, it } from "vitest";
import {
  clampWindowSize,
  getPanelDensity,
  windowSizePresets,
} from "../domain/windowSizing";

describe("window sizing", () => {
  it("exposes small, standard, and large presets", () => {
    expect(windowSizePresets).toEqual({
      small: { width: 320, height: 220 },
      standard: { width: 360, height: 260 },
      large: { width: 480, height: 420 },
    });
  });

  it("clamps sizes to the supported range", () => {
    expect(clampWindowSize({ width: 100, height: 100 })).toEqual({ width: 320, height: 220 });
    expect(clampWindowSize({ width: 900, height: 900 })).toEqual({ width: 560, height: 520 });
  });

  it("derives density without shrinking typography", () => {
    expect(getPanelDensity({ width: 320, height: 220 })).toBe("compact");
    expect(getPanelDensity({ width: 360, height: 260 })).toBe("standard");
    expect(getPanelDensity({ width: 480, height: 420 })).toBe("large");
  });
});
