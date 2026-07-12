import { mkdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const appPath = join(repoRoot, ".build", "神仙待办.app");
const distDir = join(repoRoot, "dist");
const zipPath = join(distDir, "神仙待办-0.1.0-mac-arm64.zip");

if (!existsSync(appPath)) {
  console.error("Missing .build/神仙待办.app. Run npm run native:package first.");
  process.exit(1);
}

await mkdir(distDir, { recursive: true });
await rm(zipPath, { force: true });

const result = spawnSync("/usr/bin/ditto", ["-c", "-k", "--keepParent", appPath, zipPath], {
  cwd: repoRoot,
  encoding: "utf8",
});

if (result.status !== 0) {
  if (result.stdout.trim()) console.error(result.stdout.trim());
  if (result.stderr.trim()) console.error(result.stderr.trim());
  process.exit(result.status ?? 1);
}

console.log(zipPath);
