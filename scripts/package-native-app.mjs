import { copyFile, cp, mkdir, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bundledNodeBinary = process.env.AIME_NODE_BINARY ?? resolve(process.env.HOME ?? "", ".cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node");
const nodeBinaryPath = existsSync(bundledNodeBinary) ? bundledNodeBinary : process.execPath;
const larkCliPackagePath = resolveLarkCliPackagePath();
const appRoot = join(repoRoot, ".build", "神仙待办.app");
const legacyAppRoots = [
  join(repoRoot, ".build", "小狗待办.app"),
  join(repoRoot, ".build", "Aime Companion.app"),
];
const contentsDir = join(appRoot, "Contents");
const macOSDir = join(contentsDir, "MacOS");
const resourcesDir = join(contentsDir, "Resources");
const bundledNodeDir = join(resourcesDir, "node");
const bundledLarkCliDir = join(resourcesDir, "lark-cli");
const binaryPath = join(repoRoot, ".build", "aime-companion");
const bundledBinaryPath = join(macOSDir, "aime-companion-bin");
const launcherPath = join(macOSDir, "aime-companion");
const syncScriptPath = join(repoRoot, "scripts", "aime-lark-sync.mjs");
const bundledSyncScriptPath = join(resourcesDir, "aime-lark-sync.mjs");

await rm(appRoot, { recursive: true, force: true });
for (const legacyAppRoot of legacyAppRoots) {
  await rm(legacyAppRoot, { recursive: true, force: true });
}
await mkdir(macOSDir, { recursive: true });
await mkdir(resourcesDir, { recursive: true });
await mkdir(join(bundledNodeDir, "bin"), { recursive: true });
await copyFile(binaryPath, bundledBinaryPath);
await copyFile(syncScriptPath, bundledSyncScriptPath);
await copyFile(nodeBinaryPath, join(bundledNodeDir, "bin", "node"));
if (existsSync(larkCliPackagePath)) {
  await cp(larkCliPackagePath, bundledLarkCliDir, { recursive: true });
}

await writeFile(
  launcherPath,
  [
    "#!/bin/zsh",
    "set -euo pipefail",
    'APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"',
    'RESOURCE_DIR="$APP_DIR/Contents/Resources"',
    'REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"',
    'DEFAULT_DATA_DIR="$HOME/Library/Application Support/神仙待办"',
    '# 如果 App 旁边（构建目录）已有 config，优先使用该目录，便于开发/验收；否则使用独立数据目录',
    'if [ -z "${AIME_DATA_DIR:-}" ] && [ -f "$REPO_ROOT/config/aime-base.local.json" ]; then',
    '  DATA_DIR="$REPO_ROOT"',
    'elif [ -z "${AIME_DATA_DIR:-}" ]; then',
    '  DATA_DIR="$DEFAULT_DATA_DIR"',
    'else',
    '  DATA_DIR="$AIME_DATA_DIR"',
    'fi',
    'export AIME_DATA_DIR="$DATA_DIR"',
    'export AIME_SYNC_SCRIPT_PATH="${AIME_SYNC_SCRIPT_PATH:-$RESOURCE_DIR/aime-lark-sync.mjs}"',
    'if [ -x "$RESOURCE_DIR/node/bin/node" ]; then',
    '  export PATH="$RESOURCE_DIR/node/bin:$PATH"',
    'fi',
    'if [ -x "$RESOURCE_DIR/lark-cli/bin/lark-cli" ]; then',
    '  export PATH="$RESOURCE_DIR/lark-cli/bin:$PATH"',
    'fi',
    'mkdir -p "$DATA_DIR/config" "$DATA_DIR/tmp"',
    'cd "$DATA_DIR"',
    'TASK_FEED="${AIME_TASK_FEED:-$DATA_DIR/tmp/aime-tasks.json}"',
    'mkdir -p "$(dirname "$TASK_FEED")"',
    'if [ ! -f "$TASK_FEED" ]; then',
    '  printf \'{"tasks":[]}\\n\' > "$TASK_FEED"',
    "fi",
    'exec "$APP_DIR/Contents/MacOS/aime-companion-bin" "$TASK_FEED"',
    "",
  ].join("\n"),
  { mode: 0o755 },
);

await writeFile(
  join(contentsDir, "Info.plist"),
  `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>神仙待办</string>
  <key>CFBundleExecutable</key>
  <string>aime-companion</string>
  <key>CFBundleIdentifier</key>
  <string>com.aime.companion</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>神仙待办</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026 神仙待办</string>
  <key>NSAccessibilityUsageDescription</key>
  <string>神仙待办需要辅助功能权限来读取当前输入框或窗口标题，用于未来恢复「现场」功能。</string>
  <key>NSAppleEventsUsageDescription</key>
  <string>神仙待办需要读取浏览器当前飞书链接，用来快速打开任务来源。</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>神仙待办会在你主动点击截图时识别工作窗口里的待办线索。</string>
</dict>
</plist>
`,
);

console.log(appRoot);

function resolveLarkCliPackagePath() {
  const envPath = process.env.AIME_LARK_CLI_PACKAGE_DIR;
  if (envPath && existsSync(envPath)) return envPath;

  const result = spawnSync("/usr/bin/env", ["node", "-e", [
    "const fs=require('fs');",
    "const path=require('path');",
    "const bin=process.argv[1];",
    "if (!bin) process.exit(1);",
    "const real=fs.realpathSync(bin);",
    "console.log(path.dirname(path.dirname(real)));",
  ].join(""), commandPath("lark-cli") ?? ""], {
    encoding: "utf8",
  });
  const resolved = result.status === 0 ? result.stdout.trim() : "";
  return resolved && existsSync(resolved) ? resolved : "";
}

function commandPath(command) {
  const result = spawnSync("/usr/bin/env", ["bash", "-lc", `command -v ${command}`], {
    encoding: "utf8",
  });
  return result.status === 0 ? result.stdout.trim() : undefined;
}
