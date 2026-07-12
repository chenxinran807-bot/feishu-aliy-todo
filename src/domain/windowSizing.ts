export interface WindowSize {
  width: number;
  height: number;
}

export type PanelDensity = "compact" | "standard" | "large";
export type WindowSizePreset = keyof typeof windowSizePresets;

export const windowSizePresets = {
  small: { width: 320, height: 220 },
  standard: { width: 360, height: 260 },
  large: { width: 480, height: 420 },
} as const;

export const windowSizeLimits = {
  minWidth: 320,
  minHeight: 220,
  maxWidth: 560,
  maxHeight: 520,
} as const;

export function clampWindowSize(size: WindowSize): WindowSize {
  return {
    width: Math.min(windowSizeLimits.maxWidth, Math.max(windowSizeLimits.minWidth, size.width)),
    height: Math.min(windowSizeLimits.maxHeight, Math.max(windowSizeLimits.minHeight, size.height)),
  };
}

export function getPanelDensity(size: WindowSize): PanelDensity {
  if (size.width >= 460 && size.height >= 380) return "large";
  if (size.width >= 350 && size.height >= 250) return "standard";
  return "compact";
}
