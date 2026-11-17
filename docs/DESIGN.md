# opencode-statuskit — 设计文档（V1，历史）

> **V1 历史文档。** 当前实现与安装方式见 `docs/DESIGN-V2.md`。本文保留用于对照 V1（OpenCode 1.18.x）的宿主事实、slot 机制与安装器设计。

日期：2026-09-08 · 宿主基线：OpenCode 1.18.29（stock，非 fork）· 状态：已通过三向 subagent 审查 + 端到端实测

## 1. 目标

1. 把已在个人配置中硬化的「终端标题状态」插件产品化，让他人一键安装。
2. 新增「本会话完成时间」显示：`▣ Build · 模型 · 38m 54s done 12:23`。
3. 两者独立可插拔（tui.json plugin 数组即开关），对宿主零破坏。

## 2. 宿主已验证事实（二进制逆向 + 实测）

### 2.1 slot 清单（TUI 插件唯一布局扩展点）

| slot | mode | 位置 | 占用情况 |
|---|---|---|---|
| `session_prompt_right` | append（默认） | 输入框信息行右段，紧邻 模型·计时 | **空闲**，本方案 done 落点 |
| `app_bottom` | append（默认） | 窗口最底部整行（which-key dock 用，默认禁用） | 空闲，备选落点 |
| `sidebar_footer` | single_winner | 侧边栏底部 | 内置插件占用，注册即替换 |
| `home_bottom` / `home_footer` / `sidebar_content` / `session_prompt`(replace) / `home_prompt*` / `sidebar_title` / `app` | 各异 | — | 非本方案范围 |

底栏 `▣ Build · 模型 · 时长` 本身无 slot，不可原位注入；`session_prompt_right` 渲染于同一信息行右段，实测效果：

```
▣ Build · DeepSeek V4 Pro ok · 2.3s done 12:42
```

### 2.2 外部插件响应式（核心风险，已消解）

宿主通过 Bun 插件把以下 specifier 映射到内嵌模块（单一 Solid 实例，外部插件零依赖）：
`@opentui/solid`、`@opentui/solid/components`、`@opentui/solid/jsx-runtime`、`@opentui/solid/jsx-dev-runtime`、`solid-js`、`solid-js/store`。

- 插件直接 `import { createSignal } from "solid-js"` 即可与宿主同一响应式实例
- `.tsx` 由宿主 Bun 原生转译，无构建步骤；2026-09-10 复验：不随插件提供 `tsconfig.json` 也能加载并真实渲染 JSX（自建 slot 在 home 屏渲染成功），故 kit 不再分发 tsconfig.json
- slot 渲染函数签名 `(ctx, props)`：`ctx.theme.current` 为主题；`props.session_id` 为当前会话
- **铁律：必须返回 JSX 组件（box/text），返回裸字符串会触发 Orphan text error**（#42338）；返回 null 合法（不渲染）
- 渲染抛错被宿主双层包容（try/catch → reportPluginError + ErrorBoundary），实测宿主存活、其他插件正常

### 2.3 内置标题写入器与抑制

- 内置 effect 在路由/会话数据变化时写 `OC | …` / `OpenCode`
- 抑制开关只有两个：kv `terminal_title_enabled`（挂载时一次性读取，kv store 异步加载存在启动竞态——实证不可靠）与 `OPENCODE_DISABLE_TERMINAL_TITLE`（effect 内同步判断，竞态免疫）→ **必须走环境变量**
- 兜底：本 kit 的 title 插件每秒无条件重写标题（无去重），任何外部覆盖 ≤1s 自愈；env 缺失时功能不失效，仅偶发闪烁
- 官方已有可配置 terminal_title 的 open PR，未来可能内置本功能，届时 title 插件可退役

### 2.4 kv.json 危害（已从安装方案移除）

`~/.local/state/opencode/kv.json` 为全文件快照 + last-writer-wins：运行中写入会被活实例回写覆盖，且 kv 仅在 TUI 组件挂载时读取（需重启）。安装脚本**不写 kv**，只投环境变量。

## 3. 插件规格

### 3.1 status-title.js（终端标题）

- 状态机：🔴（pendingCount>0【权限/提问挂起，读 store 权威数据】∨ status=retry ∨ session.error 且当前状态非 busy）＞ 🟡（busy）＞ 🟢（idle）
- session.error 仅在非 busy 时点亮红灯（吸收型 stream error 不污染健康运行期）；idle 时清除 >10s 的旧错误（含该会话整个子树；死亡 turn 保持红灯至下一 busy——多窗口场景的"需要关注"信号）；任一会话转 busy 时清除其自身及整个子树的错误标记（子 agent 失败后其自身不会再 busy，用户继续任意祖先会话即视为已知悉，避免父标题永久卡 🔴）
- 标题缓存：默认标题（`New session - <ISO>` 正则，与 core 逐字一致）不入缓存；fetch 负缓存 30s；事件写入优先于 fetch 回写（keepTitle）
- 控制字符剥离 C0/DEL/C1/零宽/双向符；compact 按 code point 截断；setTitle 整体 try/catch
- 开关：`OPENCODE_DISABLE_STATUS_TITLE` 为真值（非空、非 `0`/`false`）时整体停用

### 3.2 status-done.tsx（完成时间）

- 事件：`session.idle` → 记录该会话完成时刻；`session.status=busy` → 清除记录
- 渲染：`session_prompt_right` 查表输出 `done HH:MM`（跨天 `MM-DD HH:MM`），fg 用 `theme.textMuted`，`flexShrink:0` + `wrapMode:"none"`；无记录返回 null
- 纯内存态，重启即清（会话历史有更准信息，不做持久化）；`session.deleted` 时清理该会话记录
- 开关：`OPENCODE_STATUSKIT_DONE=0` 整体停用

## 4. 安装/卸载规格（install.sh / uninstall.sh）

- POSIX sh（macOS bash 3.2 兼容），`set -eu`
- 文件（现存档于 `archive/v1/`）：`status-title.js`、`status-done.tsx` → `~/.config/opencode/tui-plugins/`；`--without-title` 只拷 done 并只注册 done（不动 shell rc）
- tui.json：不存在则整写；存在则 node 合并（严格 JSON；JSONC/无 node → 打印手动指令 exit 2，不碰 keybinds——非法 keybind 值会导致 TUI 启动失败）
- rc 投放（仅 title 功能）：标记块 `# >>> opencode-statuskit >>>`（幂等 + 卸载可清除）；追加前若文件末尾无换行先补 `\n`（否则 `>>>` 被解析为重定向，破坏 rc）；zsh → `${ZDOTDIR:-$HOME}/.zshenv`；bash → `.bashrc`（检测 Debian 交互守卫 `case $- in`，插入守卫之前）+ `.bash_profile`；fish → `${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish`（`set -gx`）；`$SHELL` 检测 + `--shell` 覆盖；未知/空 shell → 打印手动指引并 `exit 2`（文件已装，仅 env 未注入）
- 提示：tmux 环境不自动刷新（给出 `tmux set-environment -g` 命令）；运行中实例需重启生效
- 卸载：反向清除全部痕迹（标记块、插件文件、tui.json 条目，原子写）；不删除 `tsconfig.json`（kit 不再分发；避免误删同目录其他插件共享的配置）；kv 不动

## 5. 开发与测试（不影响运行中的实例与真实配置）

隔离配方（四件套 + 内存 DB，实测 sha256 零接触真实配置/状态/auth）：

```bash
cd <scratch-dir>
mkdir -p dev-config/opencode dev-state dev-data
cp <repo>/plugins dev-config/... 或用 tui.json 相对路径引用 repo 插件
XDG_CONFIG_HOME=$PWD/dev-config \
XDG_STATE_HOME=$PWD/dev-state \
XDG_DATA_HOME=$PWD/dev-data \
OPENCODE_DB=:memory: \
opencode --print-logs
```

要点：
- `OPENCODE_TUI_CONFIG`/`OPENCODE_CONFIG` 是**叠加**而非替代，完全隔离必须用 XDG 重定向
- tui.json 中相对路径以 tui.json 所在目录为基准
- 运行实例只在启动时读配置；磁盘变化不影响已运行实例
- 伪终端验证：`script -q -f -c "…" capture.bin` 抓 OSC/屏幕文本

## 6. 验证记录

1. 三向独立 subagent 审查：隔离/安装安全、slot 渲染与响应式、跨平台与生态对照（2026-09-08）
2. 端到端实测：隔离配方下 status-done 原型加载 → 真实会话 idle → `done 12:42` 渲染于目标位置；真实配置 sha256 零变化
3. 生态对照：无等价先例（zellij-indicator 仅 zellij；statusline 仅 sidebar；rich-footer 依赖作者 fork 且不在 npm）；install.sh 形态与 cockpit 同流派，按其模式加固
4. 中期可选：发布 npm 包（`exports["./tui"]` + `engines.opencode` 版本声明）支持 `opencode plugin add`；install.sh 保留为 env 投放 + 离线安装路径
5. 2026-09-10 复审修复（1.18.30 隔离复验）：rc 无尾换行注入语法错误、`--without-title` 语义、未知 shell 退出码、移除 tsconfig（实测无 tsconfig 可加载+渲染）、uninstall 原子写且不再误删 tsconfig、title 开关 `0/false` 语义、done 插件 `session.deleted` 清理
