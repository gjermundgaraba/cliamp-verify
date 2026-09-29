# Save to playlist

A user writes the highlighted track to a local playlist with `w`, picking an existing playlist or creating a new one. The track is stored on disk and can be listed and loaded back from the CLI.

## Sub-features

- `save-open` opens the `Write to Playlist` picker for the highlighted track.
- `save-new` creates a new playlist with the track.
- `save-existing` appends to an existing playlist and skips duplicates.
- `save-readback` lists the playlist from `cliamp playlist list` and loads it with `cliamp load`.

## How to get to it (user POV)

- Press `w` on a playlist row (header `[Playlist]`). The picker lists saved playlists (`Favorites · 0 tracks` on a fresh config) and a `+ New Playlist...` row.
- In the picker, `Enter` appends, `p` adds to the start instead, and `Esc` or `q` cancels.
- In a terminal: `cliamp playlist list` and `cliamp load "<name>"`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`, and no `playlists/` directory in `$VC files $RUN`.

- **Pick a track.** Move to Tone 2. Run `$VC keys $RUN Down`. The `>` cursor is on `2. Verify Artist - Tone 2`.
- **Open picker.** Press `w`. Run `$VC keys $RUN w` then `$VC wait-screen $RUN '\[Save to Playlist\]'`. The picker shows `Track: Verify Artist - Tone 2`, `Favorites · 0 tracks` and `+ New Playlist...`.
- **Create playlist.** Choose the new row and name it. Run `$VC keys $RUN Down Enter`, `$VC wait-screen $RUN 'New Playlist:'`, `$VC type $RUN 'Verify Mix'`, then `$VC keys $RUN Enter`. The view returns to `[Playlist]` and shows the notice `Added 1 to "Verify Mix"`.
- **Stored file.** Read it back. Run `$VC files $RUN 'playlists/Verify Mix.toml'`. It holds one `[[track]]` with `title = "Tone 2"` and the fixture path.
- **Duplicate skip.** Save the same track to it again. Run `$VC keys $RUN w`, then `$VC keys $RUN Down Enter` to pick `Verify Mix` (the picker now lists `Favorites`, `Verify Mix · 1 tracks`, `+ New Playlist...`), then re-read the file. The notice reads `WARN: Skipped 1 duplicates in "Verify Mix"` and the file still holds exactly one `[[track]]`.
- **CLI listing.** Run `$VC cli $RUN --save save-to-playlist/list -- playlist list`. The output has a `Verify Mix  1 tracks` row.
- **Load back.** Run `$VC cli $RUN --save save-to-playlist/load -- load "Verify Mix"` then `$VC wait-state $RUN '.total == 1 and .track.title == "Tone 2"'`. The live playlist is replaced by the saved one and starts playing.
- **Proof.** Run `$VC save $RUN 'playlists/Verify Mix.toml' save-to-playlist/file.toml` and `$VC screen $RUN save-to-playlist/loaded`.

## Gotchas

- `w` acts on the highlighted row (`>`), not on the playing row (`▶`).
- The picker rows reorder as playlists are added. Assert the cursor row on screen before pressing `Enter`.
- The notice is transient. Prove the save with the file or the CLI listing.
- `cliamp load` starts playback immediately.
- `Recently Played` appears in listings only after something has played in the run.
