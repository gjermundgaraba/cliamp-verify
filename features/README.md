# cliamp verification map

This directory is the maintained source for verifying cliamp's user-facing behavior. Read this index before driving the app, then use the matching feature file as the recipe. `$VC` is `$SKILL/scripts/vc`, where `SKILL` is this skill's directory.

## Baseline preconditions

- Launch with `RUN=$($VC up)` for TUI features or `RUN=$($VC up --daemon)` for headless ones. Both start with a stopped playlist of three fixtures: `Verify Artist - Tone 1`, `Tone 2` and `Tone 3`, each 120 s long.
- On a headless Linux box, `vc up` plays into a per-run null sink by itself; it only needs the packages in SKILL.md, Launch.
- `$VC doctor $RUN` ends with `doctor: OK` before the first drive.
- The isolated config dir starts with no `config.toml`, no saved playlists, EQ `Custom` flat, shuffle off, repeat `Off`, volume `-30`.
- Never drive an instance that this run did not start. Never call bare `cliamp`.

## Driving conventions

- Start every recipe from a fresh `up` unless its preconditions say otherwise. Runs are cheap, and a fresh run has no leftover modes or files.
- Check the header mode tag (`[Playlist]`, `[Filter]`, `[Provider]`, …) before sending keys. Keys mean different things per mode.
- Treat every command and key name as literal.
- Drive TUI features with `$VC keys` / `$VC type`, and CLI features with `$VC cli $RUN -- <subcommand>`.
- Use `$VC wait-state` / `$VC wait-screen` instead of fixed sleeps when waiting for a result.

## Proof and skip reporting

- Capture the user action and the resulting state, not only the final screen.
- TUI proof is a labeled `$VC screen` before and after, plus the matching `$VC state` value.
- CLI proof is `$VC cli $RUN --save <label> -- ...`, which records the command, stdout, stderr and exit code.
- Persistence proof is a read-back of the file in the isolated config dir (`$VC files`, `$VC save`) or a second user-facing view.
- Label artifacts `<feature-id>/<step>`.
- Report an unreachable path with the attempted command and the unmet precondition. Do not report a skipped entry point as verified through a different path.
- Finish with `$VC down $RUN` and confirm `_exit.txt` reads `pane_dead=1 exit_status=0`.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior. It then uses exactly four H2 sections in this order.

1. `Sub-features` lists short IDs with one line for each behavior.
2. `How to get to it (user POV)` lists every user entry point.
3. `Driving it with vc` starts with `Preconditions:` and uses labeled bullets that pair each user action with an exact command and observable result.
4. `Gotchas` lists traps that can waste or invalidate a verification run.

Keep implementation details out of the map. Name only user paths, stable handles, required state, commands and observable proof.

## Features

- [Playback controls](./playback.md) covers play/pause, stop, next/prev, seek and volume from keys and CLI.
- [Playlist filter](./playlist-filter.md) covers `/` fuzzy filtering, matching, empty and cancel states, and playing a match.
- [Save to playlist](./save-to-playlist.md) covers `w`, creating a local playlist, the saved file, and loading it back.
- [Shuffle and repeat](./shuffle-repeat.md) covers mode toggles from keys and CLI, and their persistence to `config.toml`.
- [Remote control and daemon](./remote-daemon.md) covers `--daemon`, `status`, `remote state/call/events`, and the UI-only errors.
- [EQ](./eq.md) covers preset cycling, `cliamp eq` presets and bands, and persistence, with two known EQ CLI bugs.
- [Themes and visualizers](./appearance.md) covers the theme picker (preview, filter, cancel), visualizer cycle, picker and full screen, the CLI, and persistence.
- [Play-next queue](./play-next.md) covers `a` marks, queue order on `next`, the `A` manager, `playnext.*` IPC, and `cliamp queue` appending to the playlist.
- [Speed and mono](./speed-mono.md) covers speed steps, the real rate change, clamping, debounced persistence, and the per-session mono toggle.
- [File browser](./file-browser.md) covers opening, navigation, filtering, appending one file, and select-and-replace.
- [Resume and history](./resume-history.md) covers the saved position on quit, one-shot resume on the next launch, and `cliamp history`.
- [Spotify](./spotify.md) covers sign-in, library browsing, loading a playlist, search and the add-to-playlist picker, read-only on the real account. Playback and writes to a throwaway playlist run only on request (`vc up --spotify`).
- [Navidrome](./navidrome.md) covers a disposable Navidrome (`vc up --server navidrome`): playlists, the `N` browser (albums, artists, sorts, filter, track actions), search, streaming playback, scrobbles checked on the server, and `provider.*` IPC, with a known `byYear`/`byGenre` sort bug.
- [Jellyfin](./jellyfin.md) covers a disposable Jellyfin (`--server jellyfin`): password and API-key auth, artist/album browsing, search, streaming, playback reporting checked on the server, restore on relaunch, and `provider.*` IPC.
- [Emby](./emby.md) covers a disposable Emby (`--server emby`): albums, load and play, search, browse and sort, IPC, token auth, and two known reporting and metadata bugs.
- [Plex](./plex.md) covers an unclaimed disposable Plex with no account (`--server plex`): the playlist and album pane, loading, MP3/FLAC streaming and seeking, and IPC, with a known empty-search bug.
- [Audiobookshelf](./audiobookshelf.md) covers the book and podcast pane, loading, streaming, progress sync and resume checked on the server, browse, search and `provider.*` IPC, with token or password login (`--server audiobookshelf`).
- [Lyrion](./lyrion.md) covers saved playlists, the artist/album browser, search, streaming playback and Basic auth against a disposable LMS (`--server lyrion`, `VC_LYRION_AUTH=password` for the password path).
