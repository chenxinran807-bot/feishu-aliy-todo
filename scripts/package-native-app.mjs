import { copyFile, mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const appRoot = join(repoRoot, ".build", "Aime Companion.app");
const contentsDir = join(appRoot, "Contents");
const macOSDir = join(contentsDir, "MacOS");
const resourcesDir = join(contentsDir, "Resources");
const binaryPath = join(repoRoot, ".build", "aime-companion");
const bundledBinaryPath = join(macOSDir, "aime-companion-bin");
const launcherPath = join(macOSDir, "aime-companion");

await rm(appRoot, { recursive: true, force: true });
await mkdir(macOSDir, { recursive: true });
await mkdir(resourcesDir, { recursive: true });
await copyFile(binaryPath, bundledBinaryPath);

await writeFile(
  launcherPath,
  [
    "#!/bin/zsh",
    "set -euo pipefail",
    'APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"',
    `REPO_DIR="\${AIME_REPO_DIR:-${repoRoot}}"`,
    'cd "$REPO_DIR"',
    'TASK_FEED="${AIME_TASK_FEED:-$REPO_DIR/tmp/aime-tasks.json}"',
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
  <string>Aime Companion</string>
  <key>CFBundleExecutable</key>
  <string>aime-companion</string>
  <key>CFBundleIdentifier</key>
  <string>com.aime.companion</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Aime Companion</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026 Aime</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>Aime uses screenshots to identify possible tasks from Feishu and other work windows.</string>
</dict>
</plist>
`,
);

console.log(appRoot);
