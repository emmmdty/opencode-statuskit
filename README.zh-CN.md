# opencode-statuskit

[English](README.md) | [中文](README.zh-CN.md)

[![CI](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml/badge.svg)](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/emmmdty/opencode-statuskit)](https://github.com/emmmdty/opencode-statuskit/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

给 **OpenCode 2 TUI** 加终端状态：不用切窗口就能看到会话在做什么。

```
🟡 | Build the release        ← 正在工作
🔴 | Build the release        ← 等权限/表单、重试，或子树停止后仍有错误
🟢 | Build the release        ← 空闲或完成
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

两个可独立安装的插件：

| 插件 | 作用 | 需要配置 |
|---|---|---|
| `status-title` | 终端窗口/标签标题显示会话状态：`🟡` 工作中、`🟢` 空闲/完成、`🔴` 需要你。包含子 agent 状态。 | `terminal.title: false`（安装器会设置） |
| `status-done` | 回合结束后在输入框信息行右侧显示 `done 12:23`。 | 无 |

当前版本：**[v2.0.2](https://github.com/emmmdty/opencode-statuskit/releases/tag/v2.0.2)**。已在 OpenCode **2.2.7**（Linux）和 **2.3.0**（Linux / Windows）实测。

## 安装

### Linux / macOS

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh                  # 两个插件
./install.sh --without-title  # 只装 done，不改已有的 title 安装
```

### Windows

```powershell
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithoutTitle
```

OpenCode 2 会从 `~/.config/opencode/plugins/<name>/tui.ts(x)` 发现本地插件并热重载，不需要重启，也不需要 shell 环境变量。

也可以从 [Release](https://github.com/emmmdty/opencode-statuskit/releases/tag/v2.0.2) 下载 `tar.gz` 或 `zip`，先校验 `SHA256SUMS` 再安装。

## 安装器做了什么

- 拷贝 `plugins/v2/status-title/tui.ts` → `<config>/plugins/status-title/tui.ts`
- 拷贝 `plugins/v2/status-done/tui.tsx` → `<config>/plugins/status-done/tui.tsx`
- 装 title 时把 `<config>/cli.json` 的 `terminal.title` 设为 `false`，避免内置 `OC | …` 写入器抢标题
- 清理 V1 的 `tui-plugins/status-title.js` / `status-done.tsx` 及其 `tui.json` / `cli.json` 旧条目
- 清理 V1 安装器写入 shell rc 的 `OPENCODE_DISABLE_TERMINAL_TITLE` 标记块
- 不新增 shell rc 改动

`install.sh` 用 `node` 合并已有的 `cli.json`。没有 Node，或文件是 JSONC（含注释/尾逗号）时，插件仍会拷贝，脚本打印手动修改步骤并以 0 退出。`install.ps1` 使用 PowerShell 自带 JSON 处理，不需要 Node。

`--shell` 仍接受但已忽略：v2 从 `cli.json` 读取标题开关，不读环境变量。

## 升级

重新运行新版本的安装器即可。安装器幂等，会保留无关的 `cli.json` 键。

```sh
git pull
./install.sh
```

Windows 重新运行 `install.ps1`。

## 卸载

```sh
./uninstall.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

卸载会删除插件目录、V1 遗留文件和条目、旧 shell rc 块；不会改 `terminal.title`。如果想恢复内置标题，手动删掉 `cli.json` 里那一行。

## 要求与兼容性

| 宿主 | 状态 |
|---|---|
| Linux，OpenCode 2.2.7 | 已测 |
| Linux，OpenCode 2.3.0 | 已测 |
| Windows，OpenCode 2.3.0 | 已测（安装器在 PowerShell 5.1 和 7 验证） |
| macOS | 安装器由 CI 覆盖；Terminal / iTerm2 的 TUI 未实测 |

- 仅支持 OpenCode 2.x；V1 插件不能在 v2 运行。
- `status-title` 需要终端支持 OSC 2 标题序列。Windows Terminal、iTerm2、Kitty、WezTerm、Ghostty、VS Code 一般可用。tmux 里改的是 pane title，外层标题取决于 `set-titles`。
- `status-done` 渲染在 `prompt.footer.status`。
- 不支持桌面 App；本工具面向终端 TUI。

## 功能开关

| 环境变量 | 作用 |
|---|---|
| `OPENCODE_DISABLE_STATUS_TITLE=1` | 停用 `status-title` |
| `OPENCODE_STATUSKIT_DONE=0` | 停用 `status-done` |

V1 的 `OPENCODE_DISABLE_TERMINAL_TITLE` 在 OpenCode 2 中不生效；请用 `cli.json` 的 `terminal.title`。

## 故障排查

- **标题不变**：确认 `cli.json` 的 `terminal.title` 是 `false`；确认终端支持 OSC 2。tmux 里看 pane title，外层标题看 `set-titles`。
- **标题闪 `OC | …`**：内置写入器还开着，把 `terminal.title` 设为 `false`。
- **`done` 不显示**：确认插件已加载（日志里无插件错误），并确认回合真的结束；运行/重试期间会隐藏。
- **`install.sh` 提示 JSONC**：手动在 `cli.json` 加 `"terminal": { "title": false }`；插件已经拷贝。
- **Windows 阻止脚本**：用 `powershell -ExecutionPolicy Bypass -File .\install.ps1` 运行，不要直接粘贴到管理员 shell。

## 安全

- 无网络请求、无遥测、无后台服务。
- 插件是两个很小的 TypeScript 文件，安装前可以直接读。
- `status-title` 只写终端标题；`status-done` 只渲染页脚文本；除了会话状态和最后 idle 时间，不读取提示词或消息内容。

## 已知限制

- `status-done` 的事件时间存在内存里，并回退到会话最后的 projected idle 标记；热加载、重连或重启后仍可能显示上次完成时间。
- 标题插件每秒重写一次，外部标题写入器的覆盖会在 1 秒内自愈；`terminal.title: false` 可以完全避免闪烁。
- 如果 OpenCode 以后内置更完整的标题配置，`status-title` 可以退役。
- 插件使用 v2 TUI API（`Plugin.define`、`prompt.footer.status`、`context.data`）。V1 代码只保留在 `archive/v1/` 供对照。

## 开发

```sh
npm install
npm test
npm run typecheck
npm run test:installer
npm run smoke   # Linux，需要 opencode 和 script(1)
```

设计与隔离测试配方见 `docs/DESIGN-V2.md`；V1 历史设计见 `docs/DESIGN.md`。

## 许可证

MIT，见 `LICENSE`。
