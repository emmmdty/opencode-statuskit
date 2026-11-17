# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| 2.0.x | yes |
| 1.x | no |

The supported host is OpenCode 2.x on Linux, macOS, and Windows.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting on this repository:

<https://github.com/emmmdty/opencode-statuskit/security/advisories/new>

Do not open a public issue for a vulnerability. Include:

- the plugin version and OpenCode version,
- the operating system and terminal,
- a minimal reproduction,
- the impact you expect.

## Scope

`opencode-statuskit` is two local TUI plugins. It makes no network requests and
has no telemetry, background service, or credential handling. The title plugin
writes the terminal title; the done plugin renders text in the prompt footer.
Both read session state exposed by the OpenCode plugin API.

The installers copy two files into the OpenCode config directory and edit
`cli.json` to set `terminal.title` to `false`. They do not add shell profile
changes.
