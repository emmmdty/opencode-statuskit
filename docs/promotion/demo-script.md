# 15-second demo script

Goal: show the three title states and the done time without narration.

## Setup

- Terminal: Windows Terminal or iTerm2, 1200x600, dark theme.
- OpenCode 2.3.0 with a session named `Build`.
- A short prompt that produces a visible permission prompt, for example a command that asks before running.
- Hide personal paths, API keys, and unrelated tabs.

## Shots

| Time | Screen | Title |
|---|---|---|
| 0-3s | Start a turn and switch to a browser | 🟡 working |
| 3-6s | Return to the permission prompt | 🔴 needs attention |
| 6-9s | Approve and let it finish | 🟡 → 🟢 |
| 9-12s | Zoom the prompt footer | `done 12:42` |
| 12-15s | Show the repo URL and install line | `github.com/emmmdty/opencode-statuskit` |

## Recording

- Use `vhs` (Charm) for a reproducible GIF, or OBS at 30fps and convert to GIF/MP4.
- Keep the GIF under 5 MB; keep the MP4 under 15 MB.
- No audio, no cursor jitter, no fake speed-up that hides the real state changes.
- If the red state requires a real permission prompt, record it; do not fake the title.
- Add a caption for the terminal title if the recording is shown on a platform that crops the window chrome.

## Output names

- `docs/media/statuskit-demo.gif`
- `docs/media/statuskit-demo.mp4`
- `docs/media/title-states.png`
- `docs/media/done-time.png`
