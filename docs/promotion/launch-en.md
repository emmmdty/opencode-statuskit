# English launch post

## Show HN

**Title:** Show HN: Terminal title status and done time for the OpenCode TUI

**Body:**

I use OpenCode in a terminal and kept switching windows to check whether a turn was still running, waiting for permission, or finished. This adds that state to the terminal title and the completion time to the prompt footer.

- 🟢 idle or finished
- 🟡 working, including subagents
- 🔴 permission/form pending, retrying, or the subtree stopped with an error
- `done 12:42` in the prompt footer

It is two small TUI plugins. No network requests, no telemetry, no daemon, no account. It works over SSH and inside tmux (the pane title changes; the outer title depends on `set-titles`).

Install:

```sh
git clone --branch v2.0.2 --depth 1 https://github.com/emmmdty/opencode-statuskit.git
cd opencode-statuskit
./install.sh
```

Windows: `install.ps1` is included and needs no Node.

Tested on OpenCode 2.2.7 and 2.3.0 on Linux, and 2.3.0 on Windows. macOS installer is covered by CI; I have not verified the TUI in Terminal/iTerm2 yet, so reports are useful.

Repo: https://github.com/emmmdty/opencode-statuskit

I would especially like feedback on tmux, VS Code, and Windows Terminal title behavior.

## OpenCode Discord / short post

Terminal title status for OpenCode 2: 🟢 idle, 🟡 working, 🔴 needs attention, plus `done HH:MM` in the prompt footer. Two small TUI plugins, no network or telemetry. Linux/Windows tested. Repo and install: https://github.com/emmmdty/opencode-statuskit

## X thread

1/ OpenCode 2 TUI now has terminal title status: 🟢 idle, 🟡 working, 🔴 needs you. Plus `done 12:42` in the prompt footer. Two small plugins, no network, no telemetry. https://github.com/emmmdty/opencode-statuskit

2/ The useful part is the red state: permission prompts, forms, retries, and stopped subagent errors surface in the title, so you can switch tabs without babysitting the terminal.

3/ Install (Linux/macOS):
`git clone --branch v2.0.2 --depth 1 https://github.com/emmmdty/opencode-statuskit.git && cd opencode-statuskit && ./install.sh`
Windows: `install.ps1`. MIT. Feedback on tmux/VS Code/Windows Terminal especially welcome.
