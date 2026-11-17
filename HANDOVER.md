# 交接文档 — opencode-statuskit（V2）

> 更新时间：2026-11-17 · 宿主基线：OpenCode **2.2.7**（Linux）/ **2.3.0**（Windows） · 设计与验证详情见 `docs/DESIGN-V2.md`
> V1 历史设计与实现记录见 `docs/DESIGN.md`；legacy 线代码在 `legacy/opencode-1/`，面向 OpenCode 1.18.x，冻结在 1.0.0。

## 0. 新窗口讨论推广先读这里

分发与推广交接已单独整理：`docs/DISTRIBUTION.md`。

一句话：`v2.0.2` 已发布，许可证、远程仓库、Windows 安装器、测试/CI、Release 校验和都已完成；npm 未发布，渠道推广未发，README 媒体素材未录。

新窗口开场提示词、渠道选择、npm 单包/双包对比、推广素材清单都在该文档。先读 §3（P0/P1/P2）和 §7（待决策问题），再开始讨论渠道与节奏。

## 1. 当前状态

| 组件 | 状态 |
|---|---|
| `plugins/v2/status-title/tui.ts` | ✅ v2 API 移植完成，隔离环境实测 🟢🟡🔴 状态与子会话传播 |
| `plugins/v2/status-done/tui.tsx` | ✅ v2 API 移植完成，隔离环境实测 `done HH:MM` 渲染 |
| `install.sh` | ✅ 改为 v2 目录式插件安装；隔离沙箱跑通安装/幂等/卸载 |
| `uninstall.sh` | ✅ 反向清理 v2 插件目录 + V1 遗留文件/条目/rc 块 |
| `install.ps1` / `uninstall.ps1` | ✅ Windows 原生安装器；PowerShell 5.1 与 7 CI 验证 |
| `legacy/opencode-1/` | ✅ OpenCode 1.18.x legacy 线，1.0.0 冻结；安装器 + 测试 |
| 根 `install.sh` | ✅ 按 `opencode --version` 主版本分派 1.x / 2.x |
| `tests/` | ✅ 13 个测试：标题状态机、done slot、Unix/PowerShell 安装器 |
| CI | ✅ Ubuntu / macOS / Windows（Node 22） |
| Release 工作流 | ✅ tag 触发 tar.gz、zip、SHA256SUMS（v2.0.2 待发） |
| `docs/DESIGN-V2.md` | ✅ v2 宿主事实、规格、隔离配方、验证记录 |
| 版本发布 | ✅ `v2.0.3`（含 OpenCode 1.x legacy 1.0.0；GitHub Release + 校验和） |
| Windows 原生 | ✅ OpenCode 2.3.0 上已安装并实测（`%USERPROFILE%\.config\opencode`） |
| npm 发布 | ⬜ 两个包已准备，未发布 |

本机状态（2026-11-12 已执行 `./install.sh`）：

- `~/.config/opencode/plugins/status-title/tui.ts`
- `~/.config/opencode/plugins/status-done/tui.tsx`
- `~/.config/opencode/cli.json` 中 `terminal.title=false`
- 旧 `~/.config/opencode/tui-plugins/` 已删除
- 运行中的 2.2.7 TUI 已热重载：插件数 14 → 16，无加载错误

## 2. 为什么 V1 失效（根因）

OpenCode 2 的三处破坏性变更：

1. **插件 API 换了**：V1 默认导出的 async 函数返回 hooks，V2 不会被调用；必须 `Plugin.define({ id, setup(context) })`。
2. **CLI 配置换了**：`tui.json(c)` → 单一全局 `cli.json`。
3. **本地插件必须是目录**：V2 发现 `<config>/plugins/<name>/tui.ts(x)`；`cli.json` 里配置的单文件路径会被日志警告后跳过。

因此旧的 `cli.json` 条目 `./tui-plugins/status-title.js`、`./tui-plugins/status-done.tsx` 在 2.2.7 下完全没有加载。旧 slot `session_prompt_right` 也不存在，事件负载从 `event.properties` 变为 `event.data`。

## 3. 隔离测试（不碰真实配置）

```bash
TEST=$(mktemp -d /tmp/sk-v2.XXXX)
mkdir -p "$TEST/config/opencode/plugins/status-title" \
         "$TEST/config/opencode/plugins/status-done" \
         "$TEST/state" "$TEST/data" "$TEST/cache"

cp <repo>/plugins/v2/status-title/tui.ts \
   "$TEST/config/opencode/plugins/status-title/"
cp <repo>/plugins/v2/status-done/tui.tsx \
   "$TEST/config/opencode/plugins/status-done/"

cat > "$TEST/config/opencode/cli.json" <<'EOF'
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "terminal": { "title": false }
}
EOF

cd /tmp
XDG_CONFIG_HOME="$TEST/config" XDG_STATE_HOME="$TEST/state" \
XDG_DATA_HOME="$TEST/data" XDG_CACHE_HOME="$TEST/cache" \
OPENCODE_DB=:memory: opencode --standalone --print-logs
```

脚本化伪终端验证：

```bash
timeout 12 script -qec "env XDG_CONFIG_HOME=$TEST/config XDG_STATE_HOME=$TEST/state \
  XDG_DATA_HOME=$TEST/data XDG_CACHE_HOME=$TEST/cache OPENCODE_DB=:memory: \
  opencode --standalone --print-logs" /tmp/sk-v2-tty.log
```

### 测试清单

| # | 操作 | 预期 |
|---|---|---|
| 1 | 启动后看日志 | `plugin reconciliation completed ... plugins=16`，无 load/initialize 错误 |
| 2 | home 路由看终端标题 | `🟢 \| OpenCode` |
| 3 | 打开/创建会话 | `🟢 \| <会话标题或项目名+短 ID>` |
| 4 | 发消息生成中 | 标题变 `🟡 \| …`；完成后变 `🟢 \| …` |
| 5 | 触发重试/错误 | 标题 `🔴 \| …`；继续会话后恢复 🟡，成功后 🟢 |
| 6 | 子 agent 失败 | 父会话标题 🔴；父会话继续生成后清除，不永久卡红 |
| 7 | 触发权限确认/提问表单 | 标题 🔴；批准/回答后恢复 |
| 8 | 一段回复结束后看输入框信息行右侧 | 出现 ` done HH:MM` |
| 9 | 再发一条消息 | `done` 消失，完成后重新出现且时间更新 |
| 10 | `OPENCODE_STATUSKIT_DONE=0` 重启 | done 不渲染；title 正常 |
| 11 | `OPENCODE_DISABLE_STATUS_TITLE=1` 重启 | title 插件不接管；done 正常 |

> 事件语义：v2 的 `session.idle` 是 deprecated 兼容事件；实现以 `session.execution.succeeded/failed/interrupted/started` 为主，`session.idle` 仅作兜底清理。

## 4. 正式安装 / 卸载

```bash
cd <repo>
./install.sh                  # 两个插件
./install.sh --without-title  # 只装 done，不改 terminal.title
./uninstall.sh                # 移除插件目录 + V1 遗留
```

install.sh 做的事：

- 拷 `plugins/v2/status-title/tui.ts` → `~/.config/opencode/plugins/status-title/tui.ts`
- 拷 `plugins/v2/status-done/tui.tsx` → `~/.config/opencode/plugins/status-done/tui.tsx`
- 用 node 更新 `~/.config/opencode/cli.json`，设置 `terminal.title=false`（仅在装 title 时）
- 删除可识别的旧 `tui-plugins/status-*.js(x)` 文件及 `tui.json`/`cli.json` 里的旧条目
- 删除旧安装器写入 shell rc 的 `OPENCODE_DISABLE_TERMINAL_TITLE` 标记块（v2 不需要）
- 不再新增 shell rc 改动

`--shell` 仍接受但会提示已不需要。

## 5. 已知问题与规避

1. **`terminal.title` 必须为 false**：装了 title 插件却让内置写入器同时工作，路由/会话变化时会出现最长约 1 秒的 `OC | …` 覆盖，随后由插件自愈。install.sh 会自动设置。
2. **不要写 `tui.json` 作为 v2 主配置**：v2 客户端配置在 `cli.json`；`tui.json` 只在 `cli.json` 缺失时用于一次性迁移。
3. **JSONC 的 cli.json**：install.sh 只处理严格 JSON；含注释/尾逗号时会打印手动指令并退出 2。不要把 keybinds 交给脚本改。
4. **插件必须返回 JSX 或 null**：slot 渲染返回裸字符串会触发 orphan text 错误。
5. **热重载**：v2 会监听本地插件目录并自动重载；无需重启。若改了 `cli.json` 中非热重载字段，TUI 也会监听 `cli.json`。
6. **非交互场景**：`opencode run`/cron 不加载 TUI 插件，属预期。
7. **版本线**：本实现基于 2.2.7 的 `@opencode/plugin/tui` API；升级次版本后建议先跑 §3 的隔离清单。

## 6. 文件清单

```
opencode-statuskit/
├── README.md                    # 用户文档（安装/升级/兼容/故障/安全）
├── HANDOVER.md                  # 本文档
├── CHANGELOG.md                 # 版本记录
├── LICENSE                      # MIT
├── SECURITY.md                  # 漏洞报告与范围
├── package.json                 # 版本元数据（private，未发布 npm）
├── .github/
│   ├── ISSUE_TEMPLATE/bug.yml   # 环境信息模板
│   └── workflows/
│       ├── ci.yml               # 三平台测试
│       └── release.yml          # tag 触发 Release 与校验和
├── docs/
│   ├── DESIGN-V2.md             # 当前设计 + v2 隔离验证记录
│   ├── DISTRIBUTION.md          # 分发与推广交接（新窗口先读）
│   ├── DESIGN.md                # V1 legacy 设计
│   ├── RELEASING.md             # 发版/回滚/npm 步骤
│   ├── releases/v2.0.3.md       # Release Notes
│   └── promotion/               # 中英文发布稿、awesome 条目、演示脚本
├── install.sh                   # 分派器：按 OpenCode 主版本选择 1.x / 2.x
├── install-v2.sh                # OpenCode 2.x 安装器（POSIX sh，幂等）
├── install.ps1                  # OpenCode 2.x Windows 安装器（PowerShell 5.1+）
├── uninstall.sh                 # OpenCode 2.x 卸载器
├── uninstall.ps1                # OpenCode 2.x Windows 卸载器
├── plugins/v2/
│   ├── status-title/            # tui.ts、package.json、README、LICENSE
│   └── status-done/             # tui.tsx、package.json、README、LICENSE
├── legacy/opencode-1/           # OpenCode 1.18.x legacy 线 1.0.0
│   ├── install.sh               # tui.json + tui-plugins + shell rc
│   ├── uninstall.sh
│   ├── plugins/status-*.js(x)
│   └── README.md
├── tests/                       # 2.x/1.x 状态机、done slot、安装器、dispatcher、smoke
└── scripts/build-test-plugin.mjs
```

## 7. 后续待办（按优先级）

1. 日常使用观察 🔴 误报/漏报（重点：权限/表单挂起、子 agent 失败、重试）
2. 真实会话里确认 `done` 与内置计时器的排列符合预期
3. Windows 侧 `install.ps1`：✅ 已写，PowerShell 5.1/7 CI 通过；真实 TUI 仍建议再跑一次
4. macOS bash/zsh 实机回归：安装器已由 CI 覆盖；Terminal/iTerm2 的 TUI 未实测
5. 分发 P0：✅ LICENSE、GitHub remote、CI、Release 工作流；待补 README 截图/GIF
6. 分发执行：✅ npm 两个独立包、英文主文档、GitHub 先发；发布稿已备，渠道发布待做
7. 可选：npm 双轨发布（`exports["./tui"]`），支持 `opencode plugin add`
8. OpenCode 1.x legacy：✅ 1.0.0 已恢复并测试；建议在 1.18.29/1.18.30 上再跑一次真实 TUI 冒烟

## 8. 2026-11-12 迁移/验证记录

- 根因确认：2.2.7 跳过单文件插件路径；旧 slot/事件负载均不兼容。
- 新插件：`Plugin.define` + `context.data.on` + `prompt.footer.status` + `context.renderer.setTerminalTitle`。
- 隔离实测（伪终端 + `OPENCODE_DB=:memory:`）：
  - 两个插件均被目录发现并加载，无错误；
  - OSC 标题序列：`🟢 → 🟡 → 🔴（retry/failure）→ 🟡 → 🟢`；
  - 子会话 busy/failure 能抬升父标题，父会话继续后清除；
  - 模拟成功 turn 后输入框右侧渲染 ` done 17:24`。
- 类型检查：`@opencode/plugin@2.2.7` + `@opentui/core@0.8.1` + `@opentui/solid@0.8.1` + `solid-js@1.9.17`，strict 通过。
- 安装器：临时 `$XDG_CONFIG_HOME` 下验证安装、幂等重跑、卸载；无关 `cli.json` 键保留。
- 真实安装：运行中的 2.2.7 热重载，插件数 14 → 16，日志无插件错误。

## 9. 2026-11-17 修复：正常运行时误亮 🔴

- 现象：会话仍在正常生成（如 `Thought · 27.3s`），终端标题却显示 🔴。
- 根因：`session.retry.scheduled` 设置的 retry 标记一直保留到整个 execution 结束；v2 的重试恢复不会触发 `session.execution.started`，也没有 `session.status=busy` 事件，所以一次瞬时重试会让标题在整个回合内保持红色。另一个来源是子 agent 失败时父会话仍在运行，错误标记压过了 🟡。
- 修复：
  - `session.step.started`、`session.reasoning.started`、`session.text.started`、`session.tool.called`、`session.compaction.started` 时清除 retry 标记。
  - `hasAttention` 先判断子树是否仍有 running；运行期间历史错误不再压过 🟡，只有整个子树停下后才显示错误 🔴。权限/表单和 retry 仍可覆盖运行状态。
- 验证：隔离测试覆盖「瞬时 retry → step.started 恢复 🟡」「父运行中子失败保持 🟡」「父停止后显示 🔴」「下一 turn 恢复 🟡」；strict 类型检查通过；真实配置热重载成功。

## 10. 2026-11-17 修复：status-done 在 Windows 2.3.0 不显示

- 现象：Windows 原生 OpenCode 2.3.0 上 `status-title` 正常，`status-done` 不出现。
- 根因：done 的 slot render 依赖组件创建时读取 signal；在部分挂载/热重载时序下不会因 signal 更新而重新渲染。
- 修复：
  - slot 改用 `<Show when={doneAt(sessionID)}>`，由 reactive computation 持有 signal 读取。
  - `doneAt` 优先用事件时间，回退到会话最新的 projected `idle` 消息；插件在回合结束后才热加载、重连或漏事件时仍能显示上次完成时间。
  - 用 session `time.busy` / running 状态避免新回合开始时显示旧 done。
- 验证：
  - Windows 2.3.0 隔离真实回合（`opencode-go`）收到 `session.execution.succeeded`，slot 重新渲染，终端截屏确认 `done 17:59` 显示在 prompt footer。
  - 热加载测试：TUI 运行中新增 done 插件，slot 正常挂载并在状态更新后渲染。
  - Linux 2.2.7 延迟事件回归仍显示 `done HH:MM`；strict 类型检查通过。
- 真实 Windows 配置已更新，运行中的 TUI 热重载；重启后也会保留上次 idle 时间作为回退。

## 11. 2026-11-17 发布工程（v2.0.2）

- 公开仓库：`emmmdty/opencode-statuskit`，MIT，`main`、`v2.0.0`、`v2.0.1`、`v2.0.2` 已推送。
- 历史清理：文档与历史 commit 中的本地路径/用户名已替换；author/committer/tagger 邮箱统一为 GitHub noreply。
- Windows：`install.ps1` / `uninstall.ps1`；Windows PowerShell 5.1 实机测试通过，CI 另跑 PowerShell 7。
- 测试：13 个用例，覆盖标题状态机、done slot、Unix 安装器和 PowerShell 安装器；`npm test`、`tsc --noEmit`、`npm run test:installer` 通过。
- 冒烟：Linux OpenCode 2.3.0 隔离启动，插件无加载错误。
- CI：Ubuntu / macOS / Windows（Node 22）全绿。
- Release：`v2.0.2` 自动构建 `tar.gz`、`zip`、`SHA256SUMS`；本地已复验校验和与 tarball 安装。
- npm：`opencode-status-title`、`opencode-status-done` 包结构已准备（`exports["./tui"]`、peerDependencies、LICENSE/README），未发布。
- 待办：README 截图/GIF、macOS Terminal/iTerm2 的 TUI 实测、npm 发布、渠道推广。

## 12. 2026-11-17 v2.0.3：OpenCode 1.x legacy 线

- 恢复 `legacy/opencode-1/`：V1 插件、`install.sh` / `uninstall.sh`、README、`VERSION=1.0.0`。
- 根 `install.sh` 读取 `opencode --version`，按主版本分派 1.x / 2.x；2.x 实现在 `install-v2.sh`。
- `install.ps1` 检测到 OpenCode 1.x 时警告并停止，提示使用 WSL + legacy 安装器。
- 测试从 13 个增加到 24 个：新增 V1 title/done 测试、legacy 安装器测试、dispatcher 测试。
- `npm run test:installer` 同时跑 2.x 和 1.x 安装器；Windows 仍跑 PowerShell 5.1/7。
- README 升级段修正：tag clone 用 `git fetch --tags` + `git checkout <tag>`，不再错误地建议 `git pull`。
- legacy 线冻结在 1.0.0；支持 Linux/macOS/WSL，原生 Windows 1.x 不支持。
- 待办：在真实 OpenCode 1.18.x 上跑一次 TUI 冒烟。
- Release：`v2.0.3` 已发布，含 tar.gz、zip、SHA256SUMS；tarball 内两套安装器测试均通过。
