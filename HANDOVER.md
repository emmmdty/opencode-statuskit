# 交接文档 — opencode-statuskit

> 交接时间：2026-09-08 · 宿主基线：OpenCode 1.18.29 · 设计与验证详情见 `docs/DESIGN.md`

## 1. 当前状态

| 组件 | 状态 |
|---|---|
| `plugins/status-title.js` | ✅ 已在本人环境中长期运行并多轮硬化（三轮 subagent 审查），直接可用 |
| `plugins/status-done.tsx` | ✅ 核心逻辑已通过隔离环境端到端实测（`· done 12:42` 渲染于输入框信息行右段、紧跟内置计时器） |
| `install.sh` / `uninstall.sh` | ✅ 已在临时 `$HOME` + XDG 沙箱跑通 24 项回归（幂等、换行、JSONC、安装/卸载往返、退出码；2026-09-10），**尚未在真实个人配置上跑过** |
| `docs/DESIGN.md` | ✅ 定稿设计 + 全部已验证宿主事实 |
| npm 发布 / install.ps1 | ⬜ 未做（中期计划，见 DESIGN.md §6） |

当前机器状态：`~/.config/opencode/tui-plugins/status-title.js` 已安装且在用；`status-done` 尚未全局安装。

## 2. 隔离测试（不碰现有配置，随便折腾）

以下命令在你的真实 `~/.config/opencode`、运行中的任务实例之外完成全部验证。复制整段执行：

```bash
cd ~/myProjects/tools/opencode-statuskit

# 1) 建立隔离沙箱
TEST=$(mktemp -d /tmp/sk-test.XXXX)
mkdir -p "$TEST/config/opencode" "$TEST/state" "$TEST/data"
ln -s "$PWD/plugins" "$TEST/plugins"

# 2) 测试用 tui.json（相对路径经符号链接指向 repo 插件）
cat > "$TEST/config/opencode/tui.json" <<'EOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "plugin": ["../../plugins/status-title.js", "../../plugins/status-done.tsx"]
}
EOF

# 3) 带上你的模型配置（含 key，测试完整个 $TEST 删掉即可）
cp ~/.config/opencode/opencode.json "$TEST/config/opencode/"

# 4) 启动测试实例（OPENCODE_DISABLE_TERMINAL_TITLE 让 title 测试不受内置写入器干扰）
cd /tmp   # 任意 scratch 目录作为会话 cwd
XDG_CONFIG_HOME="$TEST/config" XDG_STATE_HOME="$TEST/state" \
XDG_DATA_HOME="$TEST/data" OPENCODE_DB=:memory: \
OPENCODE_DISABLE_TERMINAL_TITLE=1 opencode --print-logs
```

### 测试清单

| # | 操作 | 预期 |
|---|---|---|
| 1 | 启动后看 stderr 日志 | 有 `applying tui config ... sk-test.XXXX/config/opencode/tui.json`，**无** `failed to load tui plugin` / `failed to initialize` |
| 2 | 发一条消息（如 `reply with just: ok`），等回复完成 | 输入框信息行右侧出现 ` · done HH:MM`（紧跟模型/计时之后） |
| 3 | 再发一条消息 | 生成中 `done` 消失；完成后重新出现且时间更新 |
| 4 | 生成中看终端窗口标题 | `🟡 \| …`（项目名+会话名）；完成后 `🟢 \| …` |
| 5 | `Esc` 打断一次回复 | 标题回到 🟢/🟡 正常，不出现假 🔴（MessageAbortedError 已排除） |
| 6 | 触发一次权限确认（如让它跑一条未放行命令） | 标题 🔴；批准后恢复 |
| 7 | 开关验证：`OPENCODE_STATUSKIT_DONE=0` 重启实例 | done 不渲染；title 正常 |

> 🔴 的完整触发较难现场复现（需要真实 stream error / 权限挂起）。日常使用中出现 `OC |` 字样覆盖状态且不恢复，即为回归 bug，对照 `docs/DESIGN.md` §2.3/§3.1 排查。

### 清理

```bash
rm -rf "$TEST"   # 含复制的 opencode.json（有 key），务必删除
```

## 3. 正式安装 / 卸载

```bash
cd ~/myProjects/tools/opencode-statuskit
./install.sh          # 两个插件都装；自动按 shell 注入环境变量
./install.sh --without-title   # 只装 done，不动 shell rc
./uninstall.sh        # 反向清除（文件、tui.json 条目、rc 标记块）
```

install.sh 会做的事（先看再跑）：拷 `plugins/*` → `~/.config/opencode/tui-plugins/`；合并（非覆盖）`tui.json` 的 plugin 数组；向 shell rc 追加带 `# >>> opencode-statuskit >>>` 标记的环境变量块。跑完需**重启 opencode 会话**才生效。

**本机特别注意**：你的 `~/.zshenv` 里已有一行此前手动加的 `export OPENCODE_DISABLE_TERMINAL_TITLE=1`（无标记块）。install.sh 会再追加一个标记块——两行并存无害，但建议装完后手动删掉旧的裸行，以标记块为准。

## 4. 已知问题与规避（重要）

1. **tmux**：环境变量不进入已运行的 tmux server。装完执行 `tmux set-environment -g OPENCODE_DISABLE_TERMINAL_TITLE 1` 或重启 tmux server，否则会误判"安装无效"。
2. **slot 渲染铁律**：`session_prompt_right` 渲染函数必须返回 `<box>/<text>` JSX 组件（返回裸字符串 = Orphan text error，官方 issue #42338）。改 `status-done.tsx` 时严禁返回字符串。
3. **tui.json**：install.sh 只处理严格 JSON；含注释（JSONC）时会打印手动指令退出。**不要让脚本碰 keybinds**——非法 keybind 值会让 TUI 启动直接失败。
4. **kv.json 不要写**：全文件快照、last-writer-wins，运行中写会被回写覆盖（设计已移除该步骤，勿加回来）。
5. **非交互场景**：cron/脚本子进程、GUI 直启的终端读不到 rc 环境变量 → title 功能会退化成"偶发 OC 闪烁但不失效"（≤1s 自愈），不是坏。
6. **版本线**：基于 `tui.json` 机制实测于 1.18.29 / 1.18.30（2026-09-10 于 1.18.30 复验插件加载与 JSX 渲染）。官方 v2 线在开发中（npm `next`/`beta` 为 `0.0.0-*` 快照，v2 文档已描述 `cli.json` + 包式插件发现），**尚未发布正式 2.x**；v2 落地前需重验。
7. **官方动向**：terminal_title 可配置化的 PR 已在官方 repo open；若官方内置等价功能，title 插件应退役，done 插件不受影响。

## 5. 文件清单

```
opencode-statuskit/
├── README.md              # 用户文档（安装/开关/限制）
├── HANDOVER.md            # 本文档
├── docs/DESIGN.md         # 定稿设计：宿主事实、规格、隔离配方、验证记录
├── install.sh             # POSIX sh，幂等；--shell / --without-title
├── uninstall.sh           # 反向清理
└── plugins/
    ├── status-title.js    # 终端标题状态（🟢🟡🔴，自愈式重写，负缓存，C1 剥离）
    └── status-done.tsx    # done 时间（session_prompt_right，事件驱动 signal）
```

> tsconfig.json 已移除：2026-09-10 隔离实测（无 tsconfig 下加载 + slot JSX 实渲染成功）确认宿主自行完成 JSX 转译，无需随插件分发。

## 6. 后续待办（按优先级）

1. 按 §2 清单完成一轮人工测试（重点 #3、#6 两个动态场景）
2. 真实安装 + 日常使用几天，观察 🔴 误报/漏报
3. Windows 侧：写 `install.ps1`（双 `$PROFILE` + `setx`），并在真实 Windows Terminal + PowerShell 环境验证
4. macOS bash/zsh 实机回归
5. 可选：npm 双轨发布（`exports["./tui"]` + `engines.opencode`），支持 `opencode plugin add`

## 7. 2026-09-10 修复记录

- install.sh：rc 末尾无换行时先补 `\n`（原会把标记块拼进最后一行，`>>>` 被当作重定向 → rc 语法错误、后续行不执行）；`--without-title` 现在真的只装 done；未知/空 `$SHELL` 改为 `exit 2` 并给出手动注入指引；fish 配置改走 `$XDG_CONFIG_HOME`；删除死代码并让 JSONC 的 node 报错可见；`--shell` 缺参显式报错。
- uninstall.sh：tui.json 改为 tmp+rename 原子写；不再删 `tsconfig.json`（防误删同目录其他插件共享的配置）。
- plugins/：移除 `tsconfig.json`（隔离实测不需要）；`status-title.js` 的 `OPENCODE_DISABLE_STATUS_TITLE=0/false` 不再误禁用，`basename` 改用 `node:path`（Windows 路径）；`status-done.tsx` 在 `session.deleted` 时清理内存表。
- 全部修复均在临时 `$HOME` + XDG 沙箱中回归（见 §2 配方），未触碰真实配置。
