# 分发与推广交接

> 用途：新窗口讨论 opencode-statuskit 的推广/分发时，先读本文。
> 更新时间：2026-11-17 · 当前版本：**v2.0.1** · 宿主实测：Linux OpenCode 2.2.7 / Windows 原生 OpenCode 2.3.0

## 1. 一句话状态

插件已经可用，但还不是可公开一键分发的产品。当前缺的是发布工程与分发决策，不是插件功能。

## 2. 已有资产

| 资产 | 状态 | 说明 |
|---|---|---|
| 两个 TUI 插件 | ok | `status-title`、`status-done`，v2.0.1 |
| Linux 安装器 | ok | `install.sh`，POSIX sh，幂等 |
| Windows 手动安装 | ok | 已在 Windows 2.3.0 实测 |
| Windows 安装器 | no | 缺 `install.ps1` / `uninstall.ps1` |
| macOS 实测 | no | 未在 Terminal / iTerm2 回归 |
| 文档 | warn | README、CHANGELOG、DESIGN-V2、HANDOVER 已有 |
| 版本 tag | ok | `v2.0.0`、`v2.0.1`（annotated tag，已推送） |
| 远程仓库 | ok | `emmmdty/opencode-statuskit`（public），`main` 已推送 |
| npm 发布 | no | `package.json` 为 `private: true`，无 TUI exports |
| 许可证 | ok | MIT，`LICENSE` 与 `package.json` 已补 |
| 自动化测试 / CI | no | 仓库内无测试、无 CI |

## 3. 分发就绪度

### P0 公开前必须解决（进度）

1. **许可证**：✅ MIT，`LICENSE` 与 `package.json` 已补。
2. **远程仓库**：✅ `emmmdty/opencode-statuskit`（public），`main`、`v2.0.0`、`v2.0.1` 已推送。
3. **Windows 安装器**：写 `install.ps1` / `uninstall.ps1`，在 Windows 原生 PowerShell 验证。
4. **仓库内测试**：把隔离验证固化为可重复运行的测试；至少覆盖标题状态机、done slot、安装/卸载。
5. **CI 矩阵**：Linux、macOS、Windows；OpenCode 2.2.7 与 2.3.x；Node 20+。
6. **Release 工件**：源码包、校验和、Release Notes、回滚说明。
7. **包结构决策**：✅ 两个独立 npm 包（`opencode-status-title`、`opencode-status-done`），npm 尚未发布。

### P1 公开时应有

- `cli.json` 的 JSONC 安全合并；当前只处理严格 JSON。
- 减少对 `node` 的依赖，或在没有 Node 时给出完整手动步骤。
- OpenCode 版本检查与 `doctor` 诊断命令。
- 平台/终端兼容矩阵：Windows Terminal、VS Code、tmux、iTerm2、Kitty、WezTerm。
- 故障排查、升级、卸载、回滚文档。
- README 截图或 GIF：标题三态、`done HH:MM`、安装 30 秒演示。

### P2 长期维护

- npm 发布与 `opencode plugin add` 一键安装。
- 自动更新与版本回滚策略。
- 中英文文档与 ASCII 标题回退。
- 支持策略、issue 模板、贡献指南、行为准则。

## 4. 渠道选择

| 渠道 | 安装体验 | 自动更新 | Windows | 工作量 | 建议 |
|---|---|---|---|---|---|
| GitHub 源码 + 脚本 | warn | no | warn | 低 | 先做 |
| npm 包 + `opencode plugin add` | ok | ok | ok | 中 | 后做 |
| 两者都做 | ok | ok | ok | 高 | 目标形态 |

建议路线：**先 GitHub 源码分发，再 npm 包**。GitHub 用于快速发布与收集反馈；npm 用于一键安装与更新。

## 5. npm 包结构要先定

当前仓库是两个独立插件目录。npm 的一个包只能暴露一个 `./tui` 入口。

| 方案 | 独立开关 | 发布成本 | 适用 |
|---|---|---|---|
| 两个包 | ok | warn | 用户需要独立安装 title 或 done |
| 一个合并包 | warn | ok | 追求安装简单，用 options 控制功能 |

无论选哪种，都要补：

- `exports` 的 `./tui` 入口；
- `dependencies` 中的 `@opencode/plugin`；
- `peerDependencies` 中的 `solid-js`、`@opentui/core`、`@opentui/solid`；
- `engines`、`files`、`repository`、`license`、`publishConfig`；
- npm scope 与包名（例如 `@emmmdty/opencode-status-title`）。

## 6. 推广定位与素材

**目标用户**

- 使用 OpenCode 2 TUI 的开发者；
- 希望一眼看到会话状态（🟢🟡🔴）与完成时间的人；
- 已在用 tmux / Windows Terminal / iTerm2 的终端用户。

**核心卖点**

- 两个独立小插件，无网络请求；
- 标题三态与子 agent 状态传播；
- `done HH:MM` 完成时间；
- 支持 Linux 与 Windows 原生，安装器可迁移 V1 配置；
- 代码小、可审计、无后台服务。

**需要补的推广素材**

1. 15 秒 GIF：标题从 🟡 到 🟢，footer 出现 `done`。
2. 三张截图：标题三态、done 时间、安装命令。
3. 一段 30 秒安装演示：Linux 与 Windows 各一条。
4. 兼容性表格与已知限制。
5. 一页 README 首屏：痛点、效果、安装、卸载。

**推广渠道（待新窗口讨论）**

- OpenCode Discord / GitHub Discussions；
- Reddit、Hacker News；
- 中文社区：V2EX、即刻、小红书、B 站；
- 个人博客 / X / 公众号；
- 相关 Awesome / 插件列表。

## 7. 新窗口需要先回答的问题

1. 许可证选 MIT 还是 Apache-2.0？
2. GitHub 仓库用 `emmmdty/opencode-statuskit`，还是新组织/新名字？
3. 文档英文优先、中文优先，还是双语？
4. 首发只做 GitHub，还是 GitHub + npm 同步？
5. npm 走两个独立包，还是一个合并包？
6. 谁负责发版、issue 回复和安全问题？
7. 推广节奏：先小范围试用，还是一次性公开发布？

## 8. 新窗口开场提示词

```text
Read HANDOVER.md and docs/DISTRIBUTION.md in this repo.
We want to promote opencode-statuskit v2.0.1.
Help me decide the distribution route, package structure, GitHub repo setup,
release checklist, and a two-week promotion plan.
Do not change plugin code unless a distribution requirement forces it.
Start by summarizing the P0 gaps and asking me the open decisions in section 7.
```

## 9. 事实边界

- 当前 tag 已推送 GitHub，尚无 GitHub Release。
- npm 包未发布，`package.json` 仍为 `private: true`。
- Windows 是手动安装 + 隔离实测，不是 `install.ps1`。
- macOS 未实测。
- 桌面 App 不使用这套 TUI 插件；本工具面向终端 TUI。
- `status-done` 现在会回退到会话最后的 idle 时间；重启后也可能显示上次完成时间。
