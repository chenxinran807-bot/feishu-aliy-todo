#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { accessSync, constants, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = resolve(process.env.AIME_DATA_DIR ?? dirname(dirname(fileURLToPath(import.meta.url))));
const localConfigPath = resolve(projectRoot, "config/aime-base.local.json");
const defaultConfigPath = localConfigPath;
const authStatePath = resolve(projectRoot, "tmp/aime-lark-auth.json");
const setupStatePath = resolve(projectRoot, "tmp/aime-setup-state.json");

const DEFAULT_AIME_ASSISTANT_OPEN_ID = process.env.AIME_ASSISTANT_OPEN_ID ?? "";
const DEFAULT_AIME_ASSISTANT_APP_ID = process.env.AIME_ASSISTANT_APP_ID ?? "";
const DEFAULT_AIME_ASSISTANT_CHAT_ID = process.env.AIME_ASSISTANT_CHAT_ID ?? "";
const DEFAULT_AIME_ASSISTANT_URL = "https://applink.feishu.cn/client/chat/open?openChatId=oc_31661171e477fd90c1d62de8e2f1a84d";

const [command, ...args] = process.argv.slice(2);

main();

function main() {
  switch (command) {
    case "init":
      initWorkspace({
        configPath: getFlag(args, "--config") ?? localConfigPath,
        name: getFlag(args, "--name") ?? "神仙待办库",
        tableName: getFlag(args, "--table-name") ?? "待办",
        assistantUrl: getFlag(args, "--assistant-url"),
        dryRun: hasFlag(args, "--dry-run"),
      });
      return;
    case "setup":
      setupWorkspace({
        configPath: getFlag(args, "--config") ?? localConfigPath,
        name: getFlag(args, "--name") ?? "神仙待办库",
        tableName: getFlag(args, "--table-name") ?? "待办",
        assistantOpenId: getFlag(args, "--assistant-open-id") ?? DEFAULT_AIME_ASSISTANT_OPEN_ID,
        assistantAppId: getFlag(args, "--assistant-app-id") ?? DEFAULT_AIME_ASSISTANT_APP_ID,
        assistantChatId: getFlag(args, "--assistant-chat-id") ?? DEFAULT_AIME_ASSISTANT_CHAT_ID,
      });
      return;
    case "setup-status":
      printSetupStatus();
      return;
    case "bind-assistant":
      bindAssistantCommand({
        configPath: getFlag(args, "--config") ?? localConfigPath,
        assistantOpenId: getFlag(args, "--assistant-open-id") ?? DEFAULT_AIME_ASSISTANT_OPEN_ID,
        assistantAppId: getFlag(args, "--assistant-app-id") ?? DEFAULT_AIME_ASSISTANT_APP_ID,
        assistantChatId: getFlag(args, "--assistant-chat-id") ?? DEFAULT_AIME_ASSISTANT_CHAT_ID,
        assistantId: getFlag(args, "--assistant-id"),
      });
      return;
    case "search-and-bind-assistant":
      searchAndBindAssistantCommand({
        configPath: getFlag(args, "--config") ?? localConfigPath,
        assistantName: getFlag(args, "--assistant-name") ?? process.env.AIME_ASSISTANT_NAME ?? "",
      });
      return;
    case "config":
      printJson(readConfig(getFlag(args, "--config") ?? defaultConfigPath));
      return;
    case "print-aime-config":
      printAimeConfigCommand({ configPath: getFlag(args, "--config") ?? defaultConfigPath });
      return;
    case "auth-start":
      startAuth();
      return;
    case "auth-finish":
      finishAuth();
      return;
    case "doctor":
      printJson(buildDoctorReport({
        configPath: getFlag(args, "--config") ?? defaultConfigPath,
        authPath: authStatePath,
        checkBaseAccess: !hasFlag(args, "--skip-live"),
      }));
      return;
    case "self-test":
      selfTest();
      return;
    case "fields":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      printJson(runLarkJson(["base", "+field-list", ...baseArgs(config)]));
      return;
      }
    case "migrate-context-fields":
      {
      const configPath = getFlag(args, "--config") ?? defaultConfigPath;
      const config = readConfig(configPath);
      migrateContextFields(configPath, config);
      return;
      }
    case "pull":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      pull(config);
      return;
      }
    case "create":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      createTask(config, {
        title: requireArg(args, "--title"),
        dueDate: getFlag(args, "--due-date"),
        project: getFlag(args, "--project"),
        priority: getFlag(args, "--priority"),
        sourceType: getFlag(args, "--source-type"),
        sourceUrl: getFlag(args, "--source-url"),
        details: getFlag(args, "--details") ?? getFlag(args, "--description"),
        sourceExcerpt: getFlag(args, "--source-excerpt"),
        result: getFlag(args, "--result"),
      });
      return;
      }
    case "complete":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      complete(config, requireArg(args, "--record-id"));
      return;
      }
    case "ignore":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      ignore(config, requireArg(args, "--record-id"));
      return;
      }
    case "reschedule":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      reschedule(config, requireArg(args, "--record-id"), requireArg(args, "--due-date"));
      return;
      }
    case "update":
      {
      const config = readConfig(getFlag(args, "--config") ?? defaultConfigPath);
      updateTask(config, {
        recordId: requireArg(args, "--record-id"),
        title: getFlag(args, "--title"),
        dueDate: getFlag(args, "--due-date"),
        project: getFlag(args, "--project"),
        priority: getFlag(args, "--priority"),
        status: getFlag(args, "--status"),
        sourceType: getFlag(args, "--source-type"),
        sourceUrl: getFlag(args, "--source-url"),
        details: getFlag(args, "--details") ?? getFlag(args, "--description"),
        sourceExcerpt: getFlag(args, "--source-excerpt"),
        result: getFlag(args, "--result"),
      });
      return;
      }
    default:
      printUsageAndExit();
  }
}

function startAuth() {
  const result = runLarkJson(["auth", "login", "--domain", "base", "--no-wait", "--json"]);
  if (!result.device_code || !result.verification_url) {
    console.error("Could not start Lark authorization.");
    printJson(result);
    process.exit(1);
  }
  writeJson(authStatePath, {
    deviceCode: result.device_code,
    verificationUrl: result.verification_url,
    createdAt: new Date().toISOString(),
    expiresIn: result.expires_in,
  });
  printJson({
    ok: true,
    authStatePath,
    verificationUrl: result.verification_url,
    expiresIn: result.expires_in,
  });
}

function finishAuth() {
  if (!existsSync(authStatePath)) {
    console.error("No pending Lark authorization. Start authorization first.");
    process.exit(1);
  }
  const state = JSON.parse(readFileSync(authStatePath, "utf8"));
  if (!state.deviceCode) {
    console.error("Pending Lark authorization is missing device code.");
    process.exit(1);
  }
  const result = spawnSync("lark-cli", ["auth", "login", "--device-code", state.deviceCode], {
    cwd: projectRoot,
    encoding: "utf8",
    timeout: 600000,
  });
  if (result.status !== 0) {
    if (result.error?.code === "ENOENT") {
      console.error("AIME_LARK_COMPONENT_MISSING");
    } else if (result.error?.code === "ETIMEDOUT") {
      console.error("AIME_LARK_AUTH_PENDING");
    }
    if (result.stdout.trim()) console.error(result.stdout.trim());
    if (result.stderr.trim()) console.error(result.stderr.trim());
    process.exit(result.status ?? 1);
  }
  rmSync(authStatePath, { force: true });
  printJson({ ok: true, message: "authorized" });
}

function initWorkspace({ configPath, name, tableName, assistantUrl, dryRun }) {
  if (existsSync(configPath) && !hasFlag(args, "--force") && !dryRun) {
    const config = readConfig(configPath);
    printJson({ initialized: true, reused: true, configPath, config });
    return;
  }

  const allFields = defaultFields();
  const initialFields = allFields.filter((field) => field.type !== "link");
  const deferredFields = allFields.filter((field) => field.type === "link");

  const createArgs = [
    "base",
    "+base-create",
    "--name",
    name,
    "--table-name",
    tableName,
    "--fields",
    JSON.stringify(initialFields),
    "--time-zone",
    "Asia/Shanghai",
    "--as",
    "user",
    "--format",
    "json",
  ];
  if (dryRun) createArgs.push("--dry-run");

  const envelope = runLarkJson(createArgs);
  if (dryRun) {
    printJson({ initialized: false, dryRun: true, request: envelope });
    return;
  }

  const baseToken = findStringDeep(envelope, ["app_token", "base_token", "baseToken", "token"]);
  if (!baseToken) {
    console.error("Created Base, but could not read baseToken from lark-cli response.");
    console.error(JSON.stringify(envelope, null, 2));
    process.exit(1);
  }

  const tableId = resolveTableIdWithRetry(baseToken, tableName);
  if (!tableId) {
    console.error("Created Base, but could not resolve table id for table name: " + tableName);
    process.exit(1);
  }

  for (const field of deferredFields) {
    const fieldPayload = { ...field };
    if (fieldPayload.link_table === "self") {
      fieldPayload.link_table = tableId;
    }
    runLarkJson([
      "base",
      "+field-create",
      "--base-token",
      baseToken,
      "--table-id",
      tableId,
      "--as",
      "user",
      "--format",
      "json",
      "--json",
      JSON.stringify(fieldPayload),
    ]);
  }

  const viewId = firstViewId(baseToken, tableId);
  const baseUrl = `https://bytedance.larkoffice.com/base/${baseToken}?table=${tableId}${viewId ? `&view=${viewId}` : ""}`;
  const config = buildWorkspaceConfig({
    baseToken,
    tableId,
    viewId,
    baseUrl,
    assistantUrl,
  });

  writeJson(configPath, config);
  printJson({ initialized: true, reused: false, configPath, config });
}

function setupWorkspace({ configPath, name, tableName, assistantOpenId, assistantAppId, assistantChatId }) {
  if (existsSync(configPath) && !hasFlag(args, "--force")) {
    const config = readConfig(configPath);
    writeJson(setupStatePath, { step: "already_configured", configPath, baseUrl: config.baseUrl });
    console.log(JSON.stringify({ step: "already_configured", configPath, baseUrl: config.baseUrl }));
    return;
  }

  writeJson(setupStatePath, { step: "starting", startedAt: new Date().toISOString() });

  startAuth();
  const authState = JSON.parse(readFileSync(authStatePath, "utf8"));
  const status = {
    step: "awaiting_auth",
    verificationUrl: authState.verificationUrl,
    expiresIn: authState.expiresIn,
    createdAt: authState.createdAt,
  };
  writeJson(setupStatePath, status);
  console.log(JSON.stringify(status));

  try {
    finishAuth();
  } catch {
    // finishAuth already prints errors and exits on failure
    writeJson(setupStatePath, { step: "auth_failed", at: new Date().toISOString() });
    process.exit(1);
  }

  writeJson(setupStatePath, { step: "creating_base", at: new Date().toISOString() });
  initWorkspace({
    configPath,
    name,
    tableName,
    assistantUrl: DEFAULT_AIME_ASSISTANT_URL,
    dryRun: false,
  });

  const config = readConfig(configPath);

  writeJson(setupStatePath, { step: "binding_assistant", at: new Date().toISOString() });
  const bindResult = bindAimeAssistant(config, assistantOpenId, assistantAppId, assistantChatId);

  writeJson(setupStatePath, { step: "complete", configPath, config, bindResult, at: new Date().toISOString() });
  console.log(JSON.stringify({ step: "complete", configPath, config, bindResult }));
}

function bindAssistantCommand({ configPath, assistantOpenId, assistantAppId, assistantChatId, assistantId }) {
  if (!existsSync(configPath)) {
    console.error(JSON.stringify({ ok: false, reason: "config not found: " + configPath }));
    process.exit(1);
  }
  const config = readConfig(configPath);
  let resolvedOpenId = assistantOpenId;
  let resolvedAppId = assistantAppId;
  let resolvedChatId = assistantChatId;
  if (assistantId?.trim()) {
    const id = assistantId.trim();
    if (id.startsWith("cli_")) {
      resolvedAppId = id;
    } else if (id.startsWith("ou_")) {
      resolvedOpenId = id;
    } else if (id.startsWith("oc_")) {
      resolvedChatId = id;
    } else {
      printJson({ ok: false, reason: "assistant id must start with cli_, ou_, or oc_" });
      process.exit(1);
    }
  }
  const bindResult = bindAimeAssistant(config, resolvedOpenId, resolvedAppId, resolvedChatId);
  if (bindResult.bound) {
    const assistantUrl = buildAssistantUrl(bindResult);
    if (assistantUrl) {
      config.assistantUrl = assistantUrl;
      writeJson(configPath, config);
    }
  }
  printJson({ ok: bindResult.bound, bindResult, assistantUrl: config.assistantUrl });
  if (!bindResult.bound) {
    process.exit(1);
  }
}

function buildAssistantUrl(bindResult) {
  if (bindResult.memberType === "appid" && bindResult.memberId) {
    return `https://open.larkoffice.com/app/${bindResult.memberId}/baseinfo`;
  }
  if (bindResult.memberType === "openchat" && bindResult.memberId) {
    return `https://applink.feishu.cn/client/chat/open?openChatId=${bindResult.memberId}`;
  }
  if (bindResult.memberType === "openid" && bindResult.memberId) {
    return DEFAULT_AIME_ASSISTANT_URL;
  }
  return undefined;
}

function searchAndBindAssistantCommand({ configPath, assistantName }) {
  if (!existsSync(configPath)) {
    console.error(JSON.stringify({ ok: false, reason: "config not found: " + configPath }));
    process.exit(1);
  }
  if (!assistantName?.trim()) {
    console.error(JSON.stringify({ ok: false, reason: "missing --assistant-name" }));
    process.exit(1);
  }
  const config = readConfig(configPath);
  const searchResult = searchVisibleAppByName(assistantName.trim());
  if (!searchResult.ok) {
    printJson({ ok: false, reason: searchResult.reason, scopeMissing: searchResult.scopeMissing });
    process.exit(1);
  }
  if (!searchResult.app) {
    printJson({ ok: false, reason: "assistant not found", assistantName, candidates: searchResult.candidates ?? [] });
    process.exit(1);
  }
  const appId = searchResult.app.app_id;
  const bindResult = bindAimeAssistant(config, "", appId, "");
  printJson({ ok: bindResult.bound, app: searchResult.app, bindResult });
  if (!bindResult.bound) {
    process.exit(1);
  }
}

function searchVisibleAppByName(name) {
  const result = spawnSync("lark-cli", [
    "api",
    "GET",
    "/open-apis/application/v1/user/visible_apps",
    "--params",
    JSON.stringify({ page_size: 100 }),
  ], {
    cwd: projectRoot,
    encoding: "utf8",
  });
  if (result.error?.code === "ENOENT") {
    return { ok: false, reason: "lark-cli not found" };
  }
  const stdout = result.stdout.trim();
  const stderr = result.stderr.trim();
  let response;
  try {
    response = JSON.parse(stdout || stderr);
  } catch {
    return { ok: false, reason: "invalid response from lark-cli", stdout, stderr };
  }
  if (!response.ok) {
    const scopeMissing = response.error?.type === "authorization" && response.error?.subtype === "missing_scope";
    return { ok: false, reason: response.error?.message ?? "search failed", scopeMissing, error: response.error };
  }
  const apps = response.data?.app_list ?? [];
  const candidates = apps.filter((app) =>
    app.app_name?.includes(name) || name.includes(app.app_name)
  );
  const exact = candidates.find((app) => app.app_name === name);
  return {
    ok: true,
    app: exact ?? candidates[0],
    candidates: candidates.slice(0, 10),
  };
}

function printSetupStatus() {
  if (!existsSync(setupStatePath)) {
    printJson({ step: "idle" });
    return;
  }
  printJson(JSON.parse(readFileSync(setupStatePath, "utf8")));
}

function printAimeConfigCommand({ configPath }) {
  if (!existsSync(configPath)) {
    console.error(JSON.stringify({ ok: false, reason: "config not found: " + configPath }));
    process.exit(1);
  }
  const config = readConfig(configPath);
  const userOpenId = fetchCurrentUserOpenId();
  const openIdLine = userOpenId
    ? `- user open_id：${userOpenId}`
    : "- user open_id：<请向 Aime 发送「帮我获取我的飞书 open_id」并填入>";

  const text = `请帮我配置一套 Aime Todo 自动巡检工作流，要求如下：
1. 巡检范围：飞书私聊、群聊、会议纪要、妙记逐字稿
2. 发现疑似 Todo 时，必须先私聊我发"候选待办清单"，不得直接写入 Base
3. 只有我明确确认后，才能写入 Base，并同步到飞书任务
4. 无变化时保持静默，不频繁通知
5. 只保留需要我本人执行/跟进/确认/推动/回复的事项
6. 概念讨论、已取消/转交事项、纯 FYI 不入库
7. 截止时间只有原始来源明确给出时才写入
我的配置参数：
- safety word：小助手
${openIdLine}
- base token：${config.baseToken ?? "<你的 Base Token>"}
- table id：${config.tableId ?? "<你的 Table ID>"}
- 是否开启飞书任务同步：是
- tasklist_id：<可选，如需指定任务清单 ID 则填入>`;

  printJson({ ok: true, text, baseToken: config.baseToken, tableId: config.tableId, openId: userOpenId });
}

function fetchCurrentUserOpenId() {
  const result = spawnSync("lark-cli", ["api", "GET", "/open-apis/contact/v3/users/me"], {
    cwd: projectRoot,
    encoding: "utf8",
  });
  if (result.status !== 0) return undefined;
  try {
    const parsed = JSON.parse(result.stdout.trim());
    return parsed.data?.user?.open_id;
  } catch {
    return undefined;
  }
}

function inferAssistantMemberType(id) {
  if (!id) return undefined;
  if (id.startsWith("cli_")) return "appid";
  if (id.startsWith("ou_")) return "openid";
  if (id.startsWith("oc_")) return "openchat";
  return undefined;
}

function bindAimeAssistant(config, assistantOpenId, assistantAppId, assistantChatId) {
  if (!config.baseToken) {
    return { bound: false, reason: "missing base token" };
  }

  const candidates = [
    { id: assistantAppId, fallbackType: "appid" },
    { id: assistantOpenId, fallbackType: "openid" },
    { id: assistantChatId, fallbackType: "openchat" },
  ];

  for (const candidate of candidates) {
    if (!candidate.id) continue;
    const memberType = inferAssistantMemberType(candidate.id) ?? candidate.fallbackType;
    const result = callPermissionMemberCreate(config.baseToken, memberType, candidate.id);
    if (result.ok) {
      return { bound: true, memberType, memberId: candidate.id };
    }
    // Try next candidate if this one fails
  }

  const providedIds = candidates.filter((c) => c.id).map((c) => ({ type: c.fallbackType, id: c.id }));
  if (providedIds.length === 0) {
    return { bound: false, reason: "missing assistant app_id, open_id or chat_id" };
  }
  return { bound: false, tried: providedIds, reason: "all provided assistant ids failed to bind" };
}

function callPermissionMemberCreate(baseToken, memberType, memberId) {
  const body = {
    member_type: memberType,
    member_id: memberId,
    perm: "edit",
  };
  if (memberType !== "appid") {
    body.type = "user";
  }
  const result = spawnSync(
    "lark-cli",
    [
      "drive",
      "permission.members",
      "create",
      "--token",
      baseToken,
      "--type",
      "bitable",
      "--as",
      "user",
      "--yes",
      "--format",
      "json",
      "--data",
      JSON.stringify(body),
    ],
    {
      cwd: projectRoot,
      encoding: "utf8",
      timeout: 30000,
    },
  );
  if (result.status !== 0) {
    const parsed = tryParseJson(result.stdout.trim());
    const message = parsed?.error?.message ?? result.stderr ?? result.stdout;
    return { ok: false, reason: String(message).trim() };
  }
  return { ok: true };
}

function buildWorkspaceConfig({ baseToken, tableId, viewId, baseUrl, assistantUrl }) {
  const config = {
    baseToken,
    tableId,
    viewId,
    identity: "user",
    limit: 100,
    baseUrl,
    statusOpenValue: "未开始",
    statusDoneValue: "已完成",
    statusIgnoredValue: "取消",
    mapping: defaultMapping(),
  };
  if (assistantUrl) {
    config.assistantUrl = assistantUrl;
  }
  return config;
}

function firstViewId(baseToken, tableId) {
  const viewsEnvelope = runLarkJson([
    "base",
    "+view-list",
    "--base-token",
    baseToken,
    "--table-id",
    tableId,
    "--as",
    "user",
    "--limit",
    "100",
    "--format",
    "json",
  ]);
  return findStringDeep(viewsEnvelope, ["view_id", "viewId", "id"]);
}

function resolveTableId(baseToken, tableName) {
  const tablesEnvelope = runLarkJson([
    "base",
    "+table-list",
    "--base-token",
    baseToken,
    "--as",
    "user",
    "--limit",
    "100",
    "--format",
    "json",
  ]);
  const tables = collectObjectsDeep(tablesEnvelope).filter((item) => {
    const name = item.name ?? item.table_name ?? item.tableName;
    const id = item.table_id ?? item.tableId ?? item.id;
    return typeof name === "string" && typeof id === "string";
  });
  const exact = tables.find((item) => [item.name, item.table_name, item.tableName].includes(tableName));
  const table = exact ?? tables[0];
  return table?.table_id ?? table?.tableId ?? table?.id;
}

function resolveTableIdWithRetry(baseToken, tableName, retries = 10) {
  for (let i = 0; i < retries; i++) {
    const tableId = resolveTableId(baseToken, tableName);
    if (tableId) return tableId;
    sleepMs(500);
  }
  return undefined;
}

function sleepMs(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function selfTest() {
  const baseConfig = buildWorkspaceConfig({
    baseToken: "base_token",
    tableId: "table_id",
    viewId: "view_id",
    baseUrl: "https://example.com/base/base_token?table=table_id&view=view_id",
  });
  assert(!("assistantUrl" in baseConfig), "default workspace config should not include an assistant URL");
  assert(baseConfig.mapping.details === "任务详情", "workspace config should include task details mapping");
  assert(baseConfig.mapping.sourceUrl === "来源链接", "workspace config should include source link mapping");
  assert(baseConfig.mapping.sourceExcerpt === "证据摘要", "workspace config should include evidence excerpt mapping");
  assert(baseConfig.mapping.result === "结果", "workspace config should include result mapping");
  const resumableFieldNames = ["来源", "来源链接", "任务详情", "证据摘要", "结果"];
  const defaultFieldNames = new Set(defaultFields().map((field) => field.name));
  assert(
    resumableFieldNames.every((fieldName) => defaultFieldNames.has(fieldName)),
    "default fields should include every field required to resume a task from desktop"
  );
  assert(toBaseSourceType("Enter主动捕捉") === "Codex唤起", "enter proactive captures should write to an existing Base source option");
  assert(asSourceType("Codex唤起") === "主动捕捉", "desktop pull should normalize proactive capture source labels");
  assert(asSourceType("会议纪要") === "会议纪要", "desktop pull should keep meeting-note source labels user-facing");
  assert(asSourceType("聊天记录") === "聊天记录", "desktop pull should keep chat source labels user-facing");
  assert(asSourceType("private chat") === "私聊", "desktop pull should normalize private chat sources to Chinese labels");
  assert(asSourceType("manual") === "个人创建", "desktop pull should normalize manual sources to Chinese labels");
  assert(mapRecordToTask({
    record_id: "rec_empty_source",
    fields: {
      [baseConfig.mapping.title]: "空来源任务",
      [baseConfig.mapping.status]: "未开始",
    },
  }, baseConfig.mapping).sourceType === "个人创建", "empty pulled source should default to a user-facing manual label");

  const assistantConfig = buildWorkspaceConfig({
    baseToken: "base_token",
    tableId: "table_id",
    viewId: "view_id",
    baseUrl: "https://example.com/base/base_token?table=table_id&view=view_id",
    assistantUrl: "https://example.com/assistant",
  });
  assert(assistantConfig.assistantUrl === "https://example.com/assistant", "explicit assistant URL should be preserved");

  const disconnectedDoctor = buildDoctorReport({
    configPath: resolve(projectRoot, "tmp/missing-aime-base.local.json"),
    authPath: resolve(projectRoot, "tmp/missing-aime-lark-auth.json"),
    larkCliPath: "/usr/local/bin/lark-cli",
  });
  assert(disconnectedDoctor.ok === false, "doctor should fail when local Feishu config is missing");
  assert(disconnectedDoctor.nextAction === "connect_feishu", "doctor should ask disconnected users to connect Feishu");

  const pendingDoctor = buildDoctorReport({
    configPath: resolve(projectRoot, "tmp/missing-aime-base.local.json"),
    authPath: resolve(projectRoot, "scripts/aime-lark-sync.mjs"),
    larkCliPath: "/usr/local/bin/lark-cli",
  });
  assert(pendingDoctor.nextAction === "finish_auth", "doctor should ask users to finish pending authorization first");

  const pendingWithConfigDoctor = buildDoctorReport({
    configPath: resolve(projectRoot, "config/aime-base.example.json"),
    authPath: resolve(projectRoot, "scripts/aime-lark-sync.mjs"),
    larkCliPath: "/usr/local/bin/lark-cli",
  });
  assert(pendingWithConfigDoctor.ok === false, "doctor should fail while authorization confirmation is pending even with config");
  assert(pendingWithConfigDoctor.nextAction === "finish_auth", "doctor should prioritize pending authorization over sync");

  const connectedDoctor = buildDoctorReport({
    configPath: resolve(projectRoot, "config/aime-base.example.json"),
    authPath: resolve(projectRoot, "tmp/missing-aime-lark-auth.json"),
    larkCliPath: "/usr/local/bin/lark-cli",
  });
  assert(connectedDoctor.ok === true, "doctor should pass when lark-cli and config are available");
  assert(connectedDoctor.nextAction === "sync", "doctor should suggest sync when connected");
  const legacyConfigPath = resolve(projectRoot, "tmp/aime-legacy-config.json");
  writeJson(legacyConfigPath, {
    ...baseConfig,
    mapping: {
      title: "任务名称",
      status: "状态",
      dueDate: "截止时间",
    },
  });
  const legacyDoctor = buildDoctorReport({
    configPath: legacyConfigPath,
    authPath: resolve(projectRoot, "tmp/missing-aime-lark-auth.json"),
    larkCliPath: "/usr/local/bin/lark-cli",
  });
  rmSync(legacyConfigPath, { force: true });
  assert(legacyDoctor.ok === false, "doctor should fail when context fields are missing from local config");
  assert(legacyDoctor.nextAction === "migrate_fields", "doctor should ask users to upgrade missing context fields");
  assert(
    legacyDoctor.issues.some((issue) => issue.code === "missing_context_fields"),
    "doctor should explicitly report missing context fields"
  );
  assert(
    legacyDoctor.issues.some((issue) => String(issue.message).includes("来源")),
    "doctor should include source type in missing desktop continuation fields"
  );
  assert(
    legacyDoctor.issues.some((issue) => String(issue.message).includes("证据摘要")),
    "doctor should include evidence excerpt in missing desktop continuation fields"
  );
  assert(isAuthorizationFailure("need_user_authorization token_missing base:record:read"), "authorization failures should be detected from lark-cli output");

  printJson({ ok: true, tests: 23 });
}

function assert(condition, message) {
  if (!condition) {
    console.error(`Self-test failed: ${message}`);
    process.exit(1);
  }
}

function buildDoctorReport({ configPath, authPath, larkCliPath = findExecutable("lark-cli"), checkBaseAccess = false }) {
  const hasLarkCli = Boolean(larkCliPath);
  const hasConfig = existsSync(configPath);
  const hasPendingAuth = existsSync(authPath);
  const issues = [];

  if (!hasLarkCli) {
    issues.push({
      code: "missing_lark_cli",
      message: "缺少飞书连接组件。",
      action: "安装包含飞书连接能力的完整版本，或先安装 lark-cli。",
    });
  }
  if (hasPendingAuth) {
    issues.push({
      code: "pending_auth",
      message: "飞书授权还没有确认完成。",
      action: "完成浏览器里的飞书授权后，再回到桌面端点击完成授权。",
    });
  }
  if (!hasConfig) {
    issues.push({
      code: "missing_config",
      message: "还没有创建本机飞书待办库配置。",
      action: "在桌面端点击连接飞书，系统会自动创建待办库。",
    });
  }
  if (hasConfig && !hasPendingAuth) {
    const config = readConfig(configPath);
    const missingContextFields = missingContextMappingKeys(config);
    if (missingContextFields.length > 0) {
      issues.push({
        code: "missing_context_fields",
        message: `飞书待办库缺少桌面续接字段：${missingContextFields.join("、")}。`,
        action: "在桌面端点击升级飞书字段，补齐来源、证据摘要和结果。",
      });
    }
  }

  let nextAction = !hasLarkCli
    ? "install_connector"
    : hasPendingAuth
      ? "finish_auth"
      : !hasConfig
        ? "connect_feishu"
        : issues.some((issue) => issue.code === "missing_context_fields")
          ? "migrate_fields"
          : "sync";

  if (nextAction === "sync" && checkBaseAccess) {
    const accessIssue = checkBaseReadAccess(readConfig(configPath));
    if (accessIssue) {
      issues.push(accessIssue);
      nextAction = accessIssue.code === "auth_expired" ? "reauthorize" : "sync_error";
    }
  }

  return {
    ok: issues.length === 0,
    nextAction,
    checks: {
      larkCli: hasLarkCli,
      localConfig: hasConfig,
      pendingAuth: hasPendingAuth,
    },
    paths: {
      configPath,
      authPath,
      larkCliPath: larkCliPath || null,
    },
    issues,
  };
}

function missingContextMappingKeys(config) {
  const required = ["sourceType", "sourceUrl", "details", "sourceExcerpt", "result"];
  return required
    .filter((key) => !config.mapping?.[key])
    .map((key) => defaultMapping()[key]);
}

function checkBaseReadAccess(config) {
  const result = spawnSync("lark-cli", [
    "base",
    "+record-list",
    ...baseArgs(config, { includeView: true }),
    "--limit",
    "1",
    "--format",
    "json",
  ], {
    cwd: projectRoot,
    encoding: "utf8",
  });
  if (result.status === 0) return null;
  const raw = `${result.stdout}\n${result.stderr}`;
  if (isAuthorizationFailure(raw)) {
    return {
      code: "auth_expired",
      message: "飞书授权已失效。",
      action: "在桌面端点击重新授权，完成后再点完成授权。",
    };
  }
  return {
    code: "sync_unavailable",
    message: "飞书待办库暂时不可用。",
    action: "稍后重试同步，或重新体检查看原因。",
  };
}

function isAuthorizationFailure(raw) {
  return String(raw).includes("need_user_authorization")
    || String(raw).includes("token_missing")
    || String(raw).includes("base:record:read");
}

function findExecutable(name) {
  const pathValues = (process.env.PATH ?? "").split(":").filter(Boolean);
  for (const directory of pathValues) {
    const candidate = resolve(directory, name);
    try {
      accessSync(candidate, constants.X_OK);
      return candidate;
    } catch (_) {
      // Keep scanning PATH.
    }
  }
  return undefined;
}

function defaultMapping() {
  return {
    title: "任务名称",
    status: "状态",
    dueDate: "截止时间",
    priority: "任务标签",
    sourceType: "来源",
    sourceUrl: "来源链接",
    details: "任务详情",
    sourceExcerpt: "证据摘要",
    result: "结果",
    updateRecord: "更新记录",
    larkTaskGuid: "飞书任务GUID",
    larkTaskUrl: "飞书任务链接",
    syncStatus: "飞书任务同步状态",
    sourceId: "来源ID",
    parentRecordId: "父记录",
    project: "任务类别",
    updatedAt: "飞书任务最近同步时间",
  };
}

function defaultFields() {
  return [
    { type: "text", name: "任务名称", description: "桌面面板展示的待办标题" },
    {
      type: "select",
      name: "状态",
      multiple: false,
      options: [
        { name: "未开始", hue: "Blue", lightness: "Lighter" },
        { name: "进行中", hue: "Orange", lightness: "Light" },
        { name: "已完成", hue: "Green", lightness: "Light" },
        { name: "取消", hue: "Gray", lightness: "Light" },
      ],
    },
    { type: "datetime", name: "截止时间", style: { format: "yyyy-MM-dd HH:mm" } },
    {
      type: "select",
      name: "任务标签",
      multiple: false,
      options: [
        { name: "P0", hue: "Red", lightness: "Standard" },
        { name: "P1", hue: "Orange", lightness: "Standard" },
        { name: "P2", hue: "Blue", lightness: "Light" },
        { name: "P3", hue: "Gray", lightness: "Light" },
      ],
    },
    {
      type: "select",
      name: "来源",
      multiple: true,
      options: [
        { name: "聊天记录", hue: "Blue", lightness: "Lighter" },
        { name: "会议纪要", hue: "Purple", lightness: "Lighter" },
        { name: "个人创建", hue: "Green", lightness: "Lighter" },
        { name: "Codex唤起", hue: "Orange", lightness: "Lighter" },
      ],
    },
    { type: "text", name: "来源链接", style: { type: "url" } },
    { type: "text", name: "任务详情", description: "不在桌面面板外露，点击任务后查看" },
    { type: "text", name: "证据摘要", description: "原始飞书消息、文档或会议里的关键证据摘要" },
    { type: "text", name: "结果", description: "任务产出成果或结论" },
    { type: "text", name: "更新记录", description: "任务变更历史" },
    { type: "text", name: "飞书任务GUID" },
    { type: "text", name: "飞书任务链接", style: { type: "url" } },
    { type: "text", name: "飞书任务同步状态" },
    { type: "text", name: "来源ID" },
    { type: "link", name: "父记录", link_table: "self" },
    { type: "text", name: "任务类别" },
    { type: "updated_at", name: "飞书任务最近同步时间", style: { format: "yyyy-MM-dd HH:mm" } },
  ];
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

function migrateContextFields(configPath, config) {
  const contextMappingKeys = ["sourceType", "sourceUrl", "details", "sourceExcerpt", "result"];
  const defaultMappingValues = defaultMapping();
  const contextMappings = Object.fromEntries(
    contextMappingKeys.map((key) => [key, defaultMappingValues[key]])
  );
  const fieldDefinitions = new Map(defaultFields().map((field) => [field.name, field]));
  const existingEnvelope = runLarkJson(["base", "+field-list", ...baseArgs(config)]);
  const existingNames = new Set(
    collectObjectsDeep(existingEnvelope)
      .map((item) => item.field_name ?? item.fieldName ?? item.name)
      .filter((name) => typeof name === "string" && name.trim())
  );

  const created = [];
  const alreadyExists = [];
  for (const fieldName of Object.values(contextMappings)) {
    if (existingNames.has(fieldName)) {
      alreadyExists.push(fieldName);
      continue;
    }
    runLarkJson([
      "base",
      "+field-create",
      ...baseArgs(config),
      "--json",
      JSON.stringify(fieldDefinitions.get(fieldName) ?? { type: "text", name: fieldName }),
    ]);
    created.push(fieldName);
    existingNames.add(fieldName);
  }

  const nextConfig = {
    ...config,
    mapping: {
      ...config.mapping,
      ...contextMappings,
    },
  };
  writeJson(configPath, nextConfig);
  printJson({ ok: true, created, alreadyExists, configPath, mapping: contextMappings });
}

function createTask(config, task) {
  const fields = [config.mapping.title, config.mapping.status];
  const row = [task.title, config.statusOpenValue ?? "未开始"];

  if (task.dueDate) {
    assertDateKey(task.dueDate);
    fields.push(config.mapping.dueDate);
    row.push(task.dueDate);
  }

  if (task.project && config.mapping.project) {
    fields.push(config.mapping.project);
    row.push(task.project);
  }
  if (task.priority && config.mapping.priority) {
    fields.push(config.mapping.priority);
    row.push(task.priority);
  }
  if (task.sourceType && config.mapping.sourceType) {
    fields.push(config.mapping.sourceType);
    row.push(toBaseSourceType(task.sourceType));
  }
  if (task.sourceUrl && config.mapping.sourceUrl) {
    fields.push(config.mapping.sourceUrl);
    row.push(task.sourceUrl);
  }
  if (task.details && config.mapping.details) {
    fields.push(config.mapping.details);
    row.push(task.details);
  }
  if (task.sourceExcerpt && config.mapping.sourceExcerpt) {
    fields.push(config.mapping.sourceExcerpt);
    row.push(task.sourceExcerpt);
  }
  if (task.result && config.mapping.result) {
    fields.push(config.mapping.result);
    row.push(task.result);
  }

  const payload = { fields, rows: [row] };
  printJson(runLarkJson(["base", "+record-batch-create", ...baseArgs(config), "--json", JSON.stringify(payload)]));
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

function ignore(config, recordId) {
  const patch = {
    record_id_list: [recordId],
    patch: {
      [config.mapping.status]: config.statusIgnoredValue ?? "已忽略",
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

function updateTask(config, task) {
  const patchFields = {};
  if (task.title !== undefined) {
    patchFields[config.mapping.title] = task.title;
  }
  if (task.dueDate !== undefined) {
    assertDateKey(task.dueDate);
    patchFields[config.mapping.dueDate] = task.dueDate;
  }
  if (task.project !== undefined && config.mapping.project) {
    patchFields[config.mapping.project] = task.project;
  }
  if (task.priority !== undefined && config.mapping.priority) {
    patchFields[config.mapping.priority] = task.priority;
  }
  if (task.status !== undefined && config.mapping.status) {
    patchFields[config.mapping.status] = toBaseStatus(task.status, config);
  }
  if (task.sourceType !== undefined && config.mapping.sourceType) {
    patchFields[config.mapping.sourceType] = toBaseSourceType(task.sourceType);
  }
  if (task.sourceUrl !== undefined && config.mapping.sourceUrl) {
    patchFields[config.mapping.sourceUrl] = task.sourceUrl;
  }
  if (task.details !== undefined && config.mapping.details) {
    patchFields[config.mapping.details] = task.details;
  }
  if (task.sourceExcerpt !== undefined && config.mapping.sourceExcerpt) {
    patchFields[config.mapping.sourceExcerpt] = task.sourceExcerpt;
  }
  if (task.result !== undefined && config.mapping.result) {
    patchFields[config.mapping.result] = task.result;
  }

  if (Object.keys(patchFields).length === 0) {
    console.error("Nothing to update. Provide --title, --due-date, --project, --priority, --status, --source-type, --source-url, --details, --source-excerpt, or --result.");
    process.exit(1);
  }

  const patch = {
    record_id_list: [task.recordId],
    patch: patchFields,
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
  if (result.error?.code === "ENOENT") {
    console.error("AIME_LARK_COMPONENT_MISSING");
    process.exit(1);
  }
  const stdout = result.stdout.trim();
  const stderr = result.stderr.trim();
  if (result.status !== 0) {
    explainLarkFailure(stdout, stderr, result.status);
  }

  try {
    return JSON.parse(stdout.replace(/^=== Dry Run ===\s*/s, ""));
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
  if (
    Array.isArray(envelope?.data?.data) &&
    Array.isArray(envelope?.data?.fields) &&
    Array.isArray(envelope?.data?.record_id_list)
  ) {
    return envelope.data.data.map((row, rowIndex) => ({
      record_id: envelope.data.record_id_list[rowIndex],
      fields: Object.fromEntries(envelope.data.fields.map((fieldName, columnIndex) => [fieldName, row[columnIndex]])),
    }));
  }

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
  const sourceTypes = asSourceTypes(readField(record, mapping.sourceType));
  const fallbackSourceTypes = sourceTypes.length > 0 ? sourceTypes : ["个人创建"];
  return {
    id: record.record_id,
    larkRecordId: record.record_id,
    title: asText(record.fields[mapping.title]) || "Untitled task",
    sourceType: fallbackSourceTypes[0],
    sourceTypes: fallbackSourceTypes,
    sourceUrl: asText(readField(record, mapping.sourceUrl)) || undefined,
    details: asText(readField(record, mapping.details)) || undefined,
    sourceExcerpt: asText(readField(record, mapping.sourceExcerpt)) || undefined,
    result: asText(readField(record, mapping.result)) || undefined,
    updateRecord: asText(readField(record, mapping.updateRecord)) || undefined,
    larkTaskGuid: asText(readField(record, mapping.larkTaskGuid)) || undefined,
    larkTaskUrl: asText(readField(record, mapping.larkTaskUrl)) || undefined,
    syncStatus: asText(readField(record, mapping.syncStatus)) || undefined,
    sourceId: asText(readField(record, mapping.sourceId)) || undefined,
    parentRecordId: asText(readField(record, mapping.parentRecordId)) || undefined,
    status: asTaskStatus(record.fields[mapping.status]),
    statusText: asText(record.fields[mapping.status]) || undefined,
    dueDate: asDateKey(record.fields[mapping.dueDate]),
    createdAt: asIsoDate(readField(record, mapping.createdAt)) ?? new Date().toISOString(),
    updatedAt: asIsoDate(readField(record, mapping.updatedAt)) ?? new Date().toISOString(),
    owner: asText(readField(record, mapping.owner)) || undefined,
    project: asText(readField(record, mapping.project)) || undefined,
    priority: asPriority(readField(record, mapping.priority)) || undefined,
  };
}

function readConfig(configPath) {
  if (!existsSync(configPath)) {
    console.error("AIME_LARK_NOT_CONNECTED");
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
  const absolutePath = resolve(projectRoot, outputPath);
  mkdirSync(dirname(absolutePath), { recursive: true });
  writeFileSync(absolutePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function getFlag(values, name) {
  const index = values.indexOf(name);
  return index >= 0 ? values[index + 1] : undefined;
}

function hasFlag(values, name) {
  return values.includes(name);
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
  if (["未完成", "未开始", "进行中", "todo", "open", "doing", "in_progress", "待处理", "待办"].some((item) => text.includes(item))) {
    return "open";
  }
  if (["done", "complete", "completed", "已完成", "完成"].some((item) => text.includes(item))) {
    return "done";
  }
  if (["ignored", "ignore", "已忽略", "忽略", "归档", "取消", "cancel", "canceled"].some((item) => text.includes(item))) {
    return "ignored";
  }
  if (["waiting", "blocked", "等待", "阻塞"].some((item) => text.includes(item))) {
    return "waiting";
  }
  return "open";
}

function asSourceType(value) {
  const text = asText(value).toLowerCase();
  if (!text) return undefined;
  if (text.includes("enter") || text.includes("主动") || text.includes("捕捉") || text.includes("codex") || text.includes("唤起")) {
    return "主动捕捉";
  }
  if (text.includes("meeting") || text.includes("会议") || text.includes("纪要")) return "会议纪要";
  if (text.includes("private") || text.includes("私聊")) return "私聊";
  if (text.includes("group") || text.includes("群") || text.includes("chat") || text.includes("聊天")) {
    return "聊天记录";
  }
  return "个人创建";
}

function asSourceTypes(value) {
  if (Array.isArray(value)) {
    return value.map((item) => asSourceType(item) ?? "个人创建").filter(Boolean);
  }
  const single = asSourceType(value);
  return single ? [single] : [];
}

function toBaseStatus(value, config) {
  const text = asText(value).toLowerCase();
  if (["done", "complete", "completed", "已完成", "完成"].some((item) => text.includes(item))) {
    return config.statusDoneValue ?? "已完成";
  }
  if (["ignored", "ignore", "cancel", "canceled", "取消", "忽略"].some((item) => text.includes(item))) {
    return config.statusIgnoredValue ?? "取消";
  }
  if (["doing", "in_progress", "进行中", "处理中", "开始"].some((item) => text.includes(item))) {
    return "进行中";
  }
  return config.statusOpenValue ?? "未开始";
}

function toBaseSourceType(value) {
  const text = asText(value).toLowerCase();
  if (!text) return "";
  if (text.includes("会议") || text.includes("meeting")) return "会议纪要";
  if (text.includes("聊天") || text.includes("群") || text.includes("chat")) return "聊天记录";
  if (text.includes("enter") || text.includes("主动") || text.includes("捕捉")) return "Codex唤起";
  if (text.includes("codex") || text.includes("screen") || text.includes("capture") || text.includes("唤起")) return "Codex唤起";
  if (text.includes("manual") || text.includes("个人")) return "个人创建";
  return value;
}

function asDateKey(value) {
  const dateTimePattern = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/;
  if (typeof value === "string" && dateTimePattern.test(value)) return value;
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  if (typeof value === "number") return new Date(value).toISOString().slice(0, 10);
  const text = asText(value);
  const match = text.match(/\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?/);
  return match?.[0];
}

function asPriority(value) {
  const text = asText(value).toUpperCase();
  const match = text.match(/\bP[0-3]\b/);
  return match?.[0];
}

function assertDateKey(value) {
  if (!/^\d{4}-\d{2}-\d{2}( \d{2}:\d{2}:\d{2})?$/.test(value)) {
    console.error("--due-date must use YYYY-MM-DD or YYYY-MM-DD HH:mm:ss format.");
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
  if (typeof value === "string") return extractMarkdownUrl(value.trim()) ?? value.trim();
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

function extractMarkdownUrl(value) {
  return value.match(/^\[[^\]]+\]\(([^)]+)\)$/)?.[1];
}

function tryParseJson(value) {
  try {
    return JSON.parse(value);
  } catch {
    return undefined;
  }
}

function findStringDeep(value, keys) {
  if (!value || typeof value !== "object") return undefined;
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findStringDeep(item, keys);
      if (found) return found;
    }
    return undefined;
  }
  for (const key of keys) {
    const candidate = value[key];
    if (typeof candidate === "string" && candidate.trim()) return candidate.trim();
  }
  for (const item of Object.values(value)) {
    const found = findStringDeep(item, keys);
    if (found) return found;
  }
  return undefined;
}

function collectObjectsDeep(value, result = []) {
  if (!value || typeof value !== "object") return result;
  if (Array.isArray(value)) {
    value.forEach((item) => collectObjectsDeep(item, result));
    return result;
  }
  result.push(value);
  Object.values(value).forEach((item) => collectObjectsDeep(item, result));
  return result;
}

function printJson(value) {
  console.log(JSON.stringify(value));
}

function printUsageAndExit() {
  console.error(`Usage:
  npm run lark:init -- [--name "神仙待办库"] [--table-name "待办"] [--assistant-url "https://..."] [--force]
  npm run lark:config -- [--config config/aime-base.local.json]
  npm run lark:fields -- [--config config/aime-base.example.json]
  npm run lark:migrate-context-fields -- [--config config/aime-base.local.json]
  npm run lark:pull -- [--config config/aime-base.example.json] [--out tmp/aime-tasks.json]
  npm run lark:create -- --title "Task title" [--due-date "YYYY-MM-DD HH:mm:ss"] [--project "Project"] [--priority P2] [--source-type "个人创建"] [--source-url "https://..."] [--details "Task details"] [--source-excerpt "Evidence summary"] [--result "Outcome"]
  npm run lark:complete -- --record-id rec_xxx
  npm run lark:ignore -- --record-id rec_xxx
  npm run lark:reschedule -- --record-id rec_xxx --due-date "YYYY-MM-DD HH:mm:ss"
  npm run lark:update -- --record-id rec_xxx [--title "Task title"] [--due-date "YYYY-MM-DD HH:mm:ss"] [--project "Project"] [--priority P0] [--status doing] [--source-type "聊天记录"] [--source-url "https://..."] [--details "Task details"] [--source-excerpt "Evidence summary"] [--result "Outcome"]`);
  process.exit(1);
}
