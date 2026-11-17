# Promotion kit

This directory holds launch copy and recording notes. Nothing here is posted automatically.

## Positioning

**One line:** See what your OpenCode session is doing without switching windows.

**Pain:** You start a turn, switch to the browser, and later cannot tell whether OpenCode is still working, waiting for permission, or finished.

**Difference from desktop notifications:** No webhook, daemon, account, or network. The state lives in the terminal title you already look at, so it works over SSH and inside tmux.

**Proof points:**

- `🟢` idle, `🟡` working, `🔴` needs attention.
- Subagent state propagates to the parent title.
- `done HH:MM` in the prompt footer.
- Two small TypeScript files, no network, no telemetry.
- Linux and Windows tested; macOS installer covered by CI.

## Assets

| Asset | File |
|---|---|
| English launch post | `launch-en.md` |
| Chinese launch post | `launch-zh.md` |
| Awesome list entry | `awesome-opencode.md` |
| 15-second demo script | `demo-script.md` |

## Two-week sequence

| Day | Action |
|---|---|
| 1-5 | Finish P0, run beta with 3-5 users, cut v2.0.2 |
| 6-7 | Fix beta feedback, verify release assets |
| 8 | OpenCode Discord, X, 即刻 |
| 9 | V2EX 分享创造 |
| 10 | Show HN (US morning) |
| 11 | B站 / 公众号 / 知乎, awesome-opencode PR |
| 12-14 | Answer issues, update FAQ, review metrics |

## Rules

- Do not post to HN before the release assets and install instructions are verified.
- Do not claim macOS TUI support until it is tested on Terminal/iTerm2.
- Do not claim npm install support; the packages are prepared but not published.
- Reply to every install failure with a concrete command or question.
- Do not ask for stars; ask for terminal/version reports.

## Metrics

Leading: release downloads, unique visitors, external install success reports, issue quality.

Lagging: stars, awesome-list inclusion, npm downloads after phase 2.

Target for two weeks: 5 external success reports, 30-80 stars, 1 awesome-list inclusion, 0 unresolved P0.
