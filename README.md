# cliamp-verify

An agent skill for proving that a change to [cliamp](https://github.com/bjarneo/cliamp), the terminal music player, works in the running app, not just in unit tests. It works with Claude Code and Codex. Unofficial; not part of the cliamp project.

## The idea

Unit tests don't show that a keybinding does the right thing on screen, or that a track actually plays. This skill lets a coding agent check that the way a user would:

1. **Build and launch.** It builds the cliamp checkout you're working in and starts it in a private tmux session.
2. **Isolate.** Every run gets its own home and config directory, IPC socket, test audio files and tmux server. Your real `~/.config/cliamp`, and any cliamp you have running, are never touched.
3. **Drive.** It sends keystrokes, runs `cliamp` subcommands and makes IPC calls.
4. **Observe.** It reads back screen captures, state snapshots and events, and saves them as evidence.
5. **Tear down.** It removes everything except the evidence.

`scripts/vc` does all of this. The agent follows `SKILL.md` and a recipe for the feature under test from `features/`.

Beyond local playback:
- **Media servers.** `vc up --server NAME` starts a disposable Navidrome, Jellyfin, Emby, Plex, Audiobookshelf or Lyrion server in Docker. It serves a generated test library and has a throwaway login.
- **Spotify.** Uses a separate sign-in kept in `~/.config/cliamp-verify/`. The agent plays anything or changes your library only when you say so.
- **Linux.** Runs on a disposable [clankerbox](https://github.com/gjermundgaraba/clankerbox) microVM, using the profile in `clankerbox-profile/`. See `clankerbox.md`.

## Requirements

macOS or Linux, with `go`, `tmux`, `ffmpeg`, `jq` and `git`. Docker is needed only for media servers. On Linux, building cliamp also needs the packages in `clankerbox-profile/files/debian-packages`.

## Install

Clone the repo anywhere, then link it in as a user-level skill:

```sh
git clone https://github.com/gjermundgaraba/cliamp-verify.git
ln -s "$PWD/cliamp-verify" ~/.claude/skills/verify-cliamp   # Claude Code
ln -s "$PWD/cliamp-verify" ~/.agents/skills/verify-cliamp   # Codex
```

The skill runs only when you ask for it: `/verify-cliamp` in Claude Code, `$verify-cliamp` in Codex. Run it from inside a cliamp checkout, for example "/verify-cliamp prove that the new seek keys work". One install serves every checkout and worktree.

## Layout

- `SKILL.md`: the agent's instructions, starting with the isolation rules
- `scripts/vc`: the run helper (`up`, `keys`, `screen`, `state`, `cli`, `doctor`, `down`, ...)
- `features/`: one verification recipe per cliamp feature, plus known bugs found along the way
- `scripts/servers/`, `scripts/make-library`: the disposable media servers and their test library
- `clankerbox.md`, `clankerbox-profile/`, `scripts/clankerbox-docker`: Linux runs on clankerbox
- `agents/openai.yaml`: Codex metadata (user-invoked only)

## License

MIT
