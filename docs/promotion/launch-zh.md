# 中文发布稿

## V2EX / 即刻 / 公众号标题

给 OpenCode TUI 加一个终端标题状态：🟢🟡🔴 + `done` 时间

## 正文

用 OpenCode 写代码时，我经常切到浏览器，过一会儿就不知道它还在跑、在等权限，还是已经结束了。

这个插件把状态放到终端标题里：

- 🟢 空闲或完成
- 🟡 正在工作，包含子 agent
- 🔴 等权限/表单、正在重试，或子树停止后仍有错误
- 输入框信息行右侧显示 `done 12:42`

两个很小的 TUI 插件，没有网络请求、没有遥测、没有后台服务、不需要账号。SSH 和 tmux 里也能用（tmux 改的是 pane title，外层标题取决于 `set-titles`）。仓库里还带一条 OpenCode 1.18.x 的 legacy 线（1.0.0 冻结）。

安装（Linux/macOS）：

```sh
git clone --branch v2.0.3 --depth 1 https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh
```

Windows 用仓库里的 `install.ps1`，不需要 Node。

已在 OpenCode 2.2.7 / 2.3.0 的 Linux 和 2.3.0 的 Windows 上实测。macOS 的安装器有 CI，但 Terminal/iTerm2 里的 TUI 还没实测，欢迎反馈。

仓库：https://github.com/emmmdty/opencode-statuskit

特别想听 tmux、VS Code 终端、Windows Terminal 下的标题表现。

## 短版（即刻/小红书）

OpenCode TUI 的终端标题现在会显示 🟢 空闲 / 🟡 工作中 / 🔴 需要你，输入框右侧还有 `done 12:42`。两个小插件，无网络无遥测，Linux/Windows 实测。仓库：https://github.com/emmmdty/opencode-statuskit

## B站视频脚本（3-5 分钟）

1. 痛点：切到浏览器后不知道 OpenCode 在干嘛。
2. 演示三态：🟡 工作、🔴 权限/重试、🟢 完成。
3. 演示 `done` 时间。
4. 安装：clone + `./install.sh`；Windows 用 `install.ps1`。
5. 兼容性与限制：tmux、桌面 App 不支持、macOS 待实测。
6. 结尾：MIT，欢迎提 issue 报告终端型号。
