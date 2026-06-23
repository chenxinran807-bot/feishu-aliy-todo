import type { AppSnapshot } from "./types.js";

export interface LarkSyncConfig {
  baseUrl?: string;
  tableId?: string;
  viewId?: string;
  appId?: string;
  appSecret?: string;
}

export function validateLarkConfig(config: LarkSyncConfig): string[] {
  const errors: string[] = [];
  if (!config.baseUrl) errors.push("Lark Base URL is required.");
  if (!config.tableId) errors.push("Table ID is required before live sync.");
  if (!config.appId) errors.push("Lark app ID is required before live sync.");
  if (!config.appSecret) errors.push("Lark app secret is required before live sync.");
  return errors;
}

export async function pullLarkBase(snapshot: AppSnapshot): Promise<AppSnapshot> {
  const errors = validateLarkConfig({
    baseUrl: snapshot.settings.larkBaseUrl,
    tableId: snapshot.settings.larkTableId,
    viewId: snapshot.settings.larkViewId,
    appId: process.env.LARK_APP_ID,
    appSecret: process.env.LARK_APP_SECRET,
  });

  if (errors.length > 0) {
    return {
      ...snapshot,
      syncState: "stale",
      syncMessage: "Using local sample data until Lark credentials and field mapping are configured.",
    };
  }

  return {
    ...snapshot,
    syncState: "idle",
    syncMessage: "Lark sync adapter is configured but live API calls are not enabled in this MVP slice.",
  };
}
