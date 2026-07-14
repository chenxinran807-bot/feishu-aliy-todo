# 神仙待办

飞书待办的桌面常驻层：连接飞书后，把 Base 里的任务同步到桌面面板，并用更轻、更主动的方式提醒你处理重要事项。

## 用户路径

1. 首次打开桌面端，点击「一键配置」。
2. 浏览器自动打开飞书授权页，在浏览器里点击确认授权。
3. 桌面端自动完成剩余步骤：创建「神仙待办库」、初始化字段、拉取待办并开启自动同步。
4. 如果飞书机器人绑定失败，桌面端会显示「创建飞书机器人」按钮和一个输入框。用户在[机器人配置页面](https://aime.bytedance.net/assistant)创建后，复制机器人 ID（`cli_xxx` / `ou_xxx` / `oc_xxx`）粘贴到输入框，点击「绑定飞书机器人」即可完成联动。

> 说明：飞书机器人无法通过当前 OpenAPI 自动创建。每个用户的机器人 ID 都不同，因此桌面端在自动创建 Base 后，需要用户手动提供自己的飞书机器人 ID 才能完成绑定。

排障命令：

```bash
npm run lark:bind-assistant -- --assistant-app-id cli_xxx
npm run lark:bind-assistant -- --assistant-open-id ou_xxx
npm run lark:bind-assistant -- --assistant-chat-id oc_xxx
```

连接成功后，桌面面板优先展示「同步」「飞书」入口；粘贴、截图、新增只作为补充方式。

## 本地运行

安装依赖：

```bash
npm install
```

构建并打开桌面端：

```bash
npm run native:run
```

生成可分发 zip：

```bash
npm run native:dist
```

产物会输出到：

```text
dist/神仙待办-0.1.0-mac-arm64.zip
```

当前工作树里也可以直接打开已打包 App：

```bash
open ".build/神仙待办.app"
```

打包后的 App 会自带 Node 运行时、飞书连接组件和同步脚本，用户数据默认保存在：

```text
~/Library/Application Support/神仙待办
```

开发调试时可以临时指定数据目录：

```bash
AIME_DATA_DIR="/path/to/data" open ".build/神仙待办.app"
```

测试：

```bash
npm test
```

## 飞书联动

桌面端通过 App 内置的 `aime-lark-sync.mjs` 连接飞书。打包版默认配置写入：

```text
~/Library/Application Support/神仙待办/config/aime-base.local.json
```

在开发仓库里直接跑 `npm run lark:*` 时，默认仍使用仓库内的 `config/aime-base.local.json`。这个本地配置不会提交到 Git。示例模板是：

```text
config/aime-base.example.json
```

常用排障命令：

```bash
npm run lark:setup              # 命令行执行完整开箱配置
npm run lark:setup-status       # 查看当前配置进度
npm run lark:doctor
npm run lark:init
npm run lark:pull -- --out tmp/aime-tasks.json
npm run lark:assistant-signal # 只读检查飞书机器人会话是否出现新消息
```

`lark:doctor` 只检查连接状态，不会改飞书数据。它会告诉你下一步应该连接飞书、完成授权，还是直接同步。

脚本自检：

```bash
npm run lark:self-test
```

## 桌面能力

- 从飞书 Base 拉取任务，桌面常驻展示。
- 每 15 秒增量检查飞书机器人会话；出现新的机器人消息后立即刷新 Base。
- 自动刷新飞书待办，默认 5 分钟一次，作为断网或消息检查失败时的兜底。
- 勾选完成会写回飞书；取消勾选会恢复未完成。
- 支持置顶、隐藏、筛选、优先级和来源链接。
- 点击任务可查看任务详情，详情不外露在有限面板上。
- 支持粘贴飞书聊天/会议纪要补充识别待办。
- 支持主动截图识别待办，截图只在用户点击时触发。
- 飞书不可用时可临时保存，恢复后再写回。

## 产品边界

神仙待办不是另一个本地 todo，也不是默认聊天助手。它的核心价值是：

- 飞书是任务存储和协作地。
- 飞书机器人会话只作为刷新信号；候选消息不会直接变成桌面任务，Base 始终是唯一任务数据源。
- 桌面端负责常驻、同步、轻提醒和主动浮出。
- 手动新增、粘贴、截图是补充入口，不是主路径。

已安装过旧版「小狗待办」的本机，打包版会优先复用旧数据目录，避免改名后丢失飞书连接配置。
