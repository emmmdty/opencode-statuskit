# opencode-statuskit

[English](README.md) | [中文](README.zh-CN.md)

[![CI](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml/badge.svg)](https://github.com/emmmdty/opencode-statuskit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/emmmdty/opencode-statuskit)](https://github.com/emmmdty/opencode-statuskit/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

给 **OpenCode 2 TUI** 加终端状态，并保留一条 **OpenCode 1.18.x** 的冻结 legacy 线：

```
🟡 | Build the release        ← 正在工作
🔴 | Build the release        ← 等权限/表单、重试，或子树停止后仍有错误
🟢 | Build the release        ← 空闲或完成
▣ Build · GLM-5.3-Flash · 2.3s done 12:42
```

两个可独立安装的插件：

| 插件 | 作用 | 需要配置 |
|---|---|---|
| `status-title` | 终端窗口/标签标题显示会话状态：`🟡` 工作中、`🟢` 空闲/完成、`🔴` 需要你。包含子 agent 状态。 | 2.x 用 `terminal.title: false`；1.x 用 `OPENCODE_DISABLE_TERMINAL_TITLE=1` |
| `status-done` | 回合结束后在输入框信息行右侧显示 `done 12:23`。 | 无 |

当前：OpenCode 2.x 用 **[v2.0.3](https://github.com/emmmdty/opencode-statuskit/releases/tag/v2.0.3)**；OpenCode 1.18.x 用 legacy **1.0.0**（冻结）。

## 安装

### OpenCode 2.x：Linux / macOS

```sh
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh                  # 自动检测 2.x
./install.sh --without-title  # 只装 done，不改已有的 title 安装
```

### OpenCode 2.x：Windows

```powershell
git clone https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
powershell -ExecutionPolicy Bypass -File .\install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -WithoutTitle
```

OpenCode 2 会从 `~/.config/opencode/plugins/<name>/tui.ts(x)` 发现本地插件并热重载，不需要重启，也不需要 shell 环境变量。

### OpenCode 1.x：legacy（Linux / macOS / WSL）

```sh
cd opencode-statuskit
./install.sh                      # 自动检测 1.x，调用 legacy 安装器
# 或直接运行：
./legacy/opencode-1/install.sh
./legacy/opencode-1/install.sh --without-title
./legacy/opencode-1/install.sh --shell /bin/zsh
```

legacy 线使用 `tui.json` 和 `tui-plugins/`，安装后**必须重启 OpenCode 1.x**。原生 Windows 1.x 不支持，请用 WSL。详见 [`legacy/opencode-1/README.md`](legacy/opencode-1/README.md)。

根目录 `install.sh` 会读取 `opencode --version`，按主版本分派到 1.x 或 2.x 安装器。检测不到版本时默认装 2.x，并打印 legacy 路径。

## 安装器做了什么

### OpenCode 2.x

- 拷贝 `plugins/v2/status-title/tui.ts` → `<config>/plugins/status-title/tui.ts`
- 拷贝 `plugins/v2/status-done/tui.tsx` → `<config>/plugins/status-done/tui.tsx`
- 装 title 时把 `<config>/cli.json` 的 `terminal.title` 设为 `false`
- 清理 V1 的 `tui-plugins/status-*.js(x)` 及 `tui.json` / `cli.json` 旧条目
- 清理 V1 安装器写入 shell rc 的 `OPENCODE_DISABLE_TERMINAL_TITLE` 标记块
- 不新增其他 shell rc 改动

`install.sh` 用 `node` 合并已有的 `cli.json`。没有 Node，或文件是 JSONC 时，插件仍会拷贝，脚本打印手动修改步骤。`install.ps1` 使用 PowerShell 自带 JSON 处理，不需要 Node。

### OpenCode 1.x legacy

- 拷贝 `legacy/opencode-1/plugins/status-title.js` 和 `status-done.tsx` → `<config>/tui-plugins/`
- 把 `./tui-plugins/status-title.js` 和 `./tui-plugins/status-done.tsx` 加入 `<config>/tui.json`
- 装 title 时在 shell 配置（zsh、bash、fish）里加 `OPENCODE_DISABLE_TERMINAL_TITLE=1` 标记块
- 保留其他 `tui.json` 键和 shell 配置内容
- 幂等

## 升级

### OpenCode 2.x

重新运行新版本的安装器即可。安装器幂等，会保留无关的 `cli.json` 键。**不要先卸载。**

如果当初是 clone 某个 tag（例如 `git clone --branch v2.0.2 --depth 1`），fetch 后切到新 tag：

```sh
cd opencode-statuskit
git fetch --tags
git checkout v2.0.2   # 换成新的 release tag
./install.sh
```

如果 clone 的是 `main`：

```sh
git pull
./install.sh
```

如果是下载 tarball，下载新版本和 `SHA256SUMS`，校验后解压，在新目录运行 `./install.sh`。

Windows 更新 checkout 或解压新 zip 后，重新运行 `install.ps1`。

### OpenCode 1.x legacy

legacy 线冻结在 **1.0.0**，没有常规升级。如果发布 1.0.x 修复，下载新 release 并运行其中的 `legacy/opencode-1/install.sh`。

## 卸载

OpenCode 2.x：

```sh
./uninstall.sh
```

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

OpenCode 1.x legacy：

```sh
./legacy/opencode-1/uninstall.sh
```

2.x 卸载器也会清理残留的 V1 文件/条目和旧 shell rc 块，但不会改 `terminal.title`。legacy 卸载器保留 `tui.json` 的其他键。

## 要求与兼容性

| 宿主 | 状态 |
|---|---|
| Linux，OpenCode 2.2.7 | 已测 |
| Linux，OpenCode 2.3.0 | 已测 |
| Windows，OpenCode 2.3.0 | 已测（安装器在 PowerShell 5.1 和 7 验证） |
| macOS，OpenCode 2.x | 安装器由 CI 覆盖；Terminal / iTerm2 的 TUI 未实测 |
| Linux / macOS / WSL，OpenCode 1.18.x | legacy 1.0.0，支持并冻结 |
| 原生 Windows，OpenCode 1.x | 不支持；请用 WSL |

- 1.x 和 2.x 的插件 API 不兼容；根目录安装器按主版本分派。
- `status-title` 需要终端支持 OSC 2 标题序列。Windows Terminal、iTerm2、Kitty、WezTerm、Ghostty、VS Code 一般可用。tmux 里改的是 pane title，外层标题取决于 `set-titles`。
- `status-done` 在 2.x 渲染于 `prompt.footer.status`，在 1.x 渲染于 `session_prompt_right`。
- 不支持桌面 App；本工具面向终端 TUI。

## 功能开关

| 环境变量 | 作用 |
|---|---|
| `OPENCODE_DISABLE_STATUS_TITLE=1` | 两条线都停用 `status-title` |
| `OPENCODE_STATUSKIT_DONE=0` | 两条线都停用 `status-done` |
| `OPENCODE_DISABLE_TERMINAL_TITLE=1` | 仅 1.x：抑制内置标题写入器；legacy 安装器会添加 |

2.x 请用 `cli.json` 的 `terminal.title`，不要用 `OPENCODE_DISABLE_TERMINAL_TITLE`。

## 故障排查

- **2.x：标题不变。** 确认 `cli.json` 的 `terminal.title` 是 `false`；确认终端支持 OSC 2。tmux 里看 pane title，外层标题看 `set-titles`。
- **2.x：标题闪 `OC | …`。** 内置写入器还开着，把 `terminal.title` 设为 `false`。
- **2.x：`done` 不显示。** 确认插件已加载，并确认回合真的结束；运行/重试期间会隐藏。
- **2.x：`install.sh` 提示 JSONC。** 手动在 `cli.json` 加 `"terminal": { "title": false }`；插件已经拷贝。
- **1.x：标题不变。** 确认启动 OpenCode 的 shell 里有 `OPENCODE_DISABLE_TERMINAL_TITLE=1`，重启 OpenCode；tmux 里运行 `tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1`。
- **1.x：`done` 不显示。** 确认 `tui.json` 里有 `./tui-plugins/status-*.js(x)` 两个条目，然后重启 OpenCode。
- **Windows 阻止脚本。** 用 `powershell -ExecutionPolicy Bypass -File .\install.ps1` 运行，不要直接粘贴到管理员 shell。

## 安全

- 无网络请求、无遥测、无后台服务。
- 插件是很小的 JavaScript/TypeScript 文件，安装前可以直接读。
- `status-title` 只写终端标题；`status-done` 只渲染页脚文本；除了会话状态和最后 idle 时间，不读取提示词或消息内容。

## 已知限制

- 2.x：`status-done` 的事件时间存在内存里，并回退到会话最后的 projected idle 标记；热加载、重连或重启后仍可能显示上次完成时间。
- 2.x：标题插件每秒重写一次，外部标题写入器的覆盖会在 1 秒内自愈；`terminal.title: false` 可以完全避免闪烁。
- 1.x legacy：插件只在启动时加载，安装/升级后必须重启 OpenCode。该线冻结在 1.0.0。
- 如果 OpenCode 以后内置更完整的标题配置，`status-title` 可以退役。
- 2.x 用 `Plugin.define`、`prompt.footer.status`、`context.data`；1.x 代码在 `legacy/opencode-1/`，用 `event.properties`、`tui.json`、`session_prompt_right`。

## 开发

```sh
npm install
npm test
npm run typecheck
npm run test:installer   # Unix：同时测 1.x 和 2.x 安装器
npm run smoke            # 2.x Linux，需要 opencode 和 script(1)
```

Windows 上分别在 Windows PowerShell 5.1 和 PowerShell 7 运行 `tests\installer.test.ps1`。2.x 设计见 `docs/DESIGN-V2.md`，1.x 设计见 `docs/DESIGN.md`。

## 许可证

MIT，见 `LICENSE`。
