# File browser

A user opens a file browser from the player, walks the filesystem, filters entries, and either appends one file to the playlist or selects several and replaces the playlist with them.

## Sub-features

- `files-open` opens the browser with `o`, first at `$HOME`, later in the last visited directory.
- `files-nav` moves with `Enter`/`l` into directories, `h`/`Left` back, `~` home and `.` the working directory.
- `files-filter` filters entries with `/`.
- `files-append` appends the highlighted audio file with `Enter` and closes the browser. If nothing is playing, it also starts playback.
- `files-replace` marks files with `Space` (`✓`, with `[N selected]` in the header), then `R` asks for confirmation and replaces the playlist, and playback starts.
- `files-close` closes the browser with `Esc` or `o`.

## How to get to it (user POV)

- Playlist view (`[Playlist]`): press `o`. The header tag becomes `[Files]` and the list header reads `── Files: <dir>`.
- Inside: the keys above, plus `a` to select all visible audio files and `w` to write the selection to a local playlist.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`. The fixtures are in `/tmp/vc-RUN/music/`, and the isolated `$HOME` is `/tmp/vc-RUN/home`.

- **Open.** Press `o`. Run `$VC keys $RUN o` then `$VC wait-screen $RUN '\[Files\]'`. The list header reads `── Files: /tmp/vc-RUN/home` with `> ..`.
- **Walk to the fixtures.** Go up, filter and enter. Run `$VC keys $RUN Enter`, then `$VC wait-screen $RUN 'Files: /tmp/vc-[0-9]+ '`, which lists `home/` and `music/`. Then run `$VC keys $RUN /`, `$VC type $RUN music`, `$VC keys $RUN Enter Enter` and `$VC wait-screen $RUN 'Files: /tmp/vc-[0-9]+/music'`. The rows are `01-tone-1.mp3 ♫`, `02-tone-2.mp3 ♫` and `03-tone-3.mp3 ♫`.
- **Append one file.** Highlight Tone 3 and press `Enter`. Run `$VC keys $RUN Down Down Down Enter`. The browser closes (`[Playlist]`), the status shows `Added 1 track(s)`, and `.total` is `4`. Nothing was playing, so playback starts: `.state` is `"playing"` on `Tone 1`, the playlist's current track, not the appended Tone 3.
- **Reopen where you left off.** Run `$VC keys $RUN o`, then `$VC wait-screen $RUN 'Files: /tmp/vc-[0-9]+/music'`.
- **Select and replace.** Mark Tone 1 and Tone 2, then press `R`. Run `$VC keys $RUN Down Space Space`, then `$VC wait-screen $RUN '\[2 selected\]'`, which shows `✓ 01-tone-1.mp3` and `✓ 02-tone-2.mp3`. Then run `$VC keys $RUN R` and `$VC wait-screen $RUN 'Replace current queue\?'`. Confirm with `$VC keys $RUN Enter`. The header returns to `[Playlist]`, `.total` is `2`, and `.state` is `"playing"` on `Tone 1`.
- **Close.** Run `$VC keys $RUN o Escape`, and the header `[Playlist]` returns.
- **Proof.** Run `$VC screen $RUN files/final` and `$VC cli $RUN --save files/state -- remote call queue.list --wait`.

## Gotchas

- The browser starts at `$HOME`, which in a run is the isolated `/tmp/vc-RUN/home`. It never shows the user's real home, so keep fixture paths under `/tmp/vc-RUN/`.
- `.` jumps to the working directory of the cliamp process. That's the directory `vc up` ran from (the repo root), not the fixtures.
- In a filtered list, the first `Enter` completes the filter and the next one opens the entry.
- `Enter` on a file while stopped starts the playlist's *current* track, not the file you picked. Assert `.track.title`, not just `.state`.
- `Space` marks and then moves the cursor down. Assert the `✓` rows rather than counting key presses.
- `R` on a non-empty playlist always asks first, and `Esc` at the prompt keeps the playlist.
