#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const defaultConfigPath = resolve(projectRoot, "config/aime-base.example.json");

const [command, ...args] = process.argv.slice(2);

main();

function main() {
  const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);

  switch (command) {
    case "fields":
      printJson(runLarkJson(["base", "+field-list", ...baseArgs(config)]));
      return;
    case "pull":
      pull(config);
      return;
    case "complete":
      complete(config, requireArg(args, "--record-id"));
      return;
    case "reschedule":
      reschedule(config, requireArg(args, "--record-id"), requireArg(args, "--due-date"));
      return;
    default:
      printUsageAndExit();
  }
}

function pull(config) {
  const fieldArgs = Object.values(config.mapping)
    .filter(Boolean)
    .flatMap((fieldName) => ["--field-id", fieldName]);
  const recordEnvelope = runLarkJson([
    "base",
    "+record-list",
    ...baseArgs(config, { includeView: true }),
    ...fieldArgs,
    "--limit",
    String(config.limit ?? 100),
    "--format",
    "json",
  ]);
  const records = extractRecords(recordEnvelope);
  const tasks = records.map((record) => mapRecordToTask(record, config.mapping));
  const outputPath = getFlag(args, "--out");
  if (outputPath) {
    writeJson(outputPath, { tasks, pulledAt: new Date().toISOString() });
  }
  printJson({ tasks, count: tasks.length, pulledAt: new Date().toISOString() });
}

function complete(config, recordId) {
  const patch = {
    record_id_list: [recordId],
    patch: {
      [config.mapping.status]: config.statusDoneValue ?? "已完成",
    },
  };
  printJson(runLarkJson(["base", "+record-batch-update", ...baseArgs(config), "--json", JSON.stringify(patch)]));
}

function reschedule(config, recordId, dueDate) {
  assertDateKey(dueDate);
  const patch = {
    record_id_list: [recordId],
    patch: {
      [config.mapping.dueDate]: dueDate,
    },
  };
  printJson(runLarkJson(["base", "+record-batch-update", ...baseArgs(config), "--json", JSON.stringify(patch)]));
}

function baseArgs(config, options = {}) {
  const result = [
    "--base-token",
    config.baseToken,
    "--table-id",
    config.tableId,
    "--as",
    config.identity ?? "user",
  ];
  if (options.includeView && config.viewId) result.push("--view-id", config.viewId);
  return result;
}

function runLarkJson(larkArgs) {
  const result = spawnSync("lark-cli", larkArgs, {
    cwd: projectRoot,
    encoding: "utf8",
  });
  const stdout = result.stdout.trim();
  const stderr = result.stderr.trim();
  if (result.status !== 0) {
    explainLarkFailure(stdout, stderr, result.status);
  }

  try {
    return JSON.parse(stdout);
  } catch (error) {
    console.error("lark-cli did not return JSON. Raw output:");
    if (stdout) console.error(stdout);
    if (stderr) console.error(stderr);
    process.exit(1);
  }
}

function explainLarkFailure(stdout, stderr, status) {
  const parsed = tryParseJson(stdout);
  const rawMessage = parsed?.error?.message ?? stderr ?? stdout;
  const message = typeof rawMessage === "string" ? rawMessage : JSON.stringify(rawMessage, null, 2);
  const hint = parsed?.error?.hint;
  console.error(`Lark command failed with exit code ${status}.`);
  if (message) console.error(`Reason: ${message}`);
  if (hint) console.error(`Hint: ${hint}`);
  if (String(message).includes("need_user_authorization")) {
    console.error("Next step: run `lark-cli auth login` and grant Base scopes, then retry this command.");
  }
  process.exit(status ?? 1);
}

function extractRecords(envelope) {
  const candidates = [
    envelope?.data?.items,
    envelope?.data?.records,
    envelope?.items,
    envelope?.records,
  ];
  const records = candidates.find(Array.isArray);
  if (!records) return [];
  return records.map((item) => ({
    record_id: item.record_id ?? item.recordId ?? item.id,
    fields: item.fields ?? item.record?.fields ?? {},
  }));
}

function mapRecordToTask(record, mapping) {
  return {
    id: record.record_id,
    larkRecordId: record.record_id,
    title: asText(record.fields[mapping.title]) || "Untitled task",
    sourceType: asSourceType(readField(record, mapping.sourceType)) ?? "manual",
    sourceUrl: asText(readField(record, mapping.sourceUrl)) || undefined,
    status: asTaskStatus(record.fields[mapping.status]),
    dueDate: asDateKey(record.fields[mapping.dueDate]),
    createdAt: asIsoDate(readField(record, mapping.createdAt)) ?? new Date().toISOString(),
    updatedAt: asIsoDate(readField(record, mapping.updatedAt)) ?? new Date().toISOString(),
    owner: asText(readField(record, mapping.owner)) || undefined,
    project: asText(readField(record, mapping.project)) || undefined,
  };
}

function readConfig(configPath) {
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }
  const config = JSON.parse(readFileSync(configPath, "utf8"));
  for (const key of ["baseToken", "tableId", "mapping"]) {
    if (!config[key]) {
      console.error(`Config is missing required key: ${key}`);
      process.exit(1);
    }
  }
  for (const key of ["title", "status", "dueDate"]) {
    if (!config.mapping[key]) {
      console.error(`Config mapping is missing required field: ${key}`);
      process.exit(1);
    }
  }
  return config;
}

function writeJson(outputPath, value) {
  writeFileSync(resolve(projectRoot, outputPath), `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function getFlag(values, name) {
  const index = values.indexOf(name);
  return index >= 0 ? values[index + 1] : undefined;
}

function requireArg(values, name) {
  const value = getFlag(values, name);
  if (!value) {
    console.error(`Missing required argument: ${name}`);
    printUsageAndExit();
  }
  return value;
}

function readField(record, fieldName) {
  return fieldName ? record.fields[fieldName] : undefined;
}

function asTaskStatus(value) {
  const text = asText(value).toLowerCase();
  if (["未完成", "未开始", "todo", "open", "待处理", "待办"].some((item) => text.includes(item))) {
    return "open";
  }
  if (["done", "complete", "completed", "已完成", "完成"].some((item) => text.includes(item))) {
    return "done";
  }
  if (["waiting", "blocked", "等待", "阻塞"].some((item) => text.includes(item))) {
    return "waiting";
  }
  return "open";
}

function asSourceType(value) {
  const text = asText(value).toLowerCase();
  if (!text) return undefined;
  if (text.includes("meeting") || text.includes("会议")) return "meeting_note";
  if (text.includes("private") || text.includes("私聊")) return "private_chat";
  if (text.includes("group") || text.includes("群")) return "group_chat";
  return "manual";
}

function asDateKey(value) {
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  if (typeof value === "number") return new Date(value).toISOString().slice(0, 10);
  const text = asText(value);
  const match = text.match(/\d{4}-\d{2}-\d{2}/);
  return match?.[0];
}

function assertDateKey(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    console.error("--due-date must use YYYY-MM-DD format.");
    process.exit(1);
  }
}

function asIsoDate(value) {
  if (typeof value === "number") return new Date(value).toISOString();
  const text = asText(value);
  if (!text) return undefined;
  const date = new Date(text);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

function asText(value) {
  if (typeof value === "string") return value.trim();
  if (typeof value === "number") return String(value);
  if (Array.isArray(value)) return value.map(asText).filter(Boolean).join(", ");
  if (value && typeof value === "object") {
    if (typeof value.text === "string") return value.text.trim();
    if (typeof value.name === "string") return value.name.trim();
    if (typeof value.link === "string") return value.link.trim();
    if (typeof value.url === "string") return value.url.trim();
  }
  return "";
}

function tryParseJson(value) {
  try {
    return JSON.parse(value);
  } catch {
    return undefined;
  }
}

function printJson(value) {
  console.log(JSON.stringify(value, null, 2));
}

function printUsageAndExit() {
  console.error(`Usage:
  npm run lark:fields -- [--config config/aime-base.example.json]
  npm run lark:pull -- [--config config/aime-base.example.json] [--out tmp/aime-tasks.json]
  npm run lark:complete -- --record-id rec_xxx
  npm run lark:reschedule -- --record-id rec_xxx --due-date YYYY-MM-DD`);
  process.exit(1);
}
