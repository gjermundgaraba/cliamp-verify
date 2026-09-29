# Resume and history

cliamp remembers where a user stopped and what they played. Quitting while a local track plays saves its position. On the next launch with the same files, the first play of that track starts from the saved position. Every played track lands in `Recently Played`, which `cliamp history` prints.

## Sub-features

- `resume-save` writes `resume.json` with the path and whole seconds on a graceful quit (Ctrl+C or `q`).
- `resume-apply` starts that track from the saved position the first time it plays after a relaunch with positional files. Later plays start at 0.
- `history-record` appends played tracks to `history.toml`.
- `history-cli` lists recent plays with `cliamp history`.

## How to get to it (user POV)

- Quit cliamp while a track plays, then launch it again with the same file or directory arguments.
- Terminal: `cliamp history`.
- The local playlist `Recently Played`, shown by `cliamp playlist list` and the playlist manager (`p`).

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`, and no `resume.json` or `history.toml` in `$VC files $RUN`.

- **Play past the start.** Play Tone 2 and seek. Run `$VC keys $RUN Down Enter`, `$VC wait-state $RUN '.state == "playing" and .track.title == "Tone 2"'` and `$VC cli $RUN -- seek 40`. `.position` is about 40-42.
- **Quit saves.** Run `$VC restart $RUN` (a graceful Ctrl+C, then a relaunch with the same arguments). Then run `$VC files $RUN resume.json`, which reads `{"path":"/tmp/vc-RUN/music/02-tone-2.mp3","position_sec":41}` (seconds may vary by one).
- **Relaunch doesn't autoplay.** After the restart, `.state` is `"stopped"` on `Tone 1` with no `.position`.
- **First play resumes.** Run `$VC keys $RUN Down Enter`, then `$VC wait-state $RUN '.track.title == "Tone 2" and .position >= 40'`.
- **Only once.** Play Tone 1, then Tone 2 again. Run `$VC keys $RUN Up Enter`, then `$VC wait-state $RUN '.track.title == "Tone 1"'`. Then run `$VC keys $RUN Down Enter` and `$VC wait-state $RUN '.track.title == "Tone 2" and .position < 5'`.
- **History.** Run `$VC cli $RUN --save history/cli -- history`. It prints `Recently Played (N tracks)` with `Verify Artist - Tone 2  (just now)` first. `$VC files $RUN history.toml` has `[[entry]]` blocks with `path`, `title = "Tone 2"` and `played_at`.
- **Proof.** Run `$VC save $RUN resume.json history/resume.json` and `$VC save $RUN history.toml history/history.toml`.

## Gotchas

- Resume needs positional files: `vc up` passes the fixture dir, so it applies. A launch with no arguments (radio default) or `--empty` doesn't resume local tracks.
- Nothing resumes automatically. The saved position is only used when the user plays that track, and only the first time.
- Stopping (`s`) and then quitting doesn't write `resume.json`, because only a position above 0 is saved. The same goes for quitting before anything played. An older `resume.json` stays as it was and still applies on the next launch. Delete it (`rm /tmp/vc-RUN/home/.config/cliamp/resume.json`) when a recipe needs a clean slate.
- `vc down` also quits gracefully, so a run's final `_cliamp.log` and config reflect a clean exit.
