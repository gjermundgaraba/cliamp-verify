# Lyrion

A user points cliamp at a Lyrion Music Server (LMS) and plays its library. cliamp reads the library over JSON-RPC and downloads each file from `/music/<id>/download`, so no Squeezebox player is involved. It lists the server's saved playlists, has an artist and album browser (`N`), and searches the server (`Ctrl+F`). A password-protected server uses HTTP Basic auth. The provider is read-only: cliamp writes nothing to LMS.

## Sub-features

- `lyr-playlists` lists LMS saved playlists in the provider pane (`── lyrion / Playlists`). There's no track count, and `Enter` loads the playlist without playing it.
- `lyr-browse` is `N`: `By Album`, `By Artist` and `By Artist / Album`. In the album list, `s` cycles `By Name` / `Recently Added`. In an album's track list, `Enter` plays the highlighted track and appends it and the rest of the album, `a` appends every track, and `R` replaces the playlist after a confirmation.
- `lyr-search` is `Ctrl+F`, which searches track titles, albums and artists on the server. It shows a `── Tracks` section, or `No results`.
- `lyr-play` streams `lyrion://track/<id>` rows through cliamp's engine. They are seekable with a known duration, the header shows `● Streaming`, and the footer shows download progress (`↓ 0.5 / 0.5 MB (100%)`). MP3 and FLAC both play.
- `lyr-auth` sends Basic auth when `user` and `password` are set. A wrong password fails with a clear message.
- `lyr-ipc` covers `provider.playlists`, `tracks`, `search`, `artists`, `artist_albums`, `albums` (with `sorts` `album` and `new`), `album_tracks`, `load` and `load_album`. `provider.catalog` and `provider.favorite` are rejected as unsupported.

## How to get to it (user POV)

- There's no shortcut key. Choose the source in the playlist view: `Tab` goes to `SRC [...]`, `Right` until `SRC [Lyrion] 4/4`, then `Enter`. Or start cliamp with `--provider lyrion`.
- In the provider pane, `Enter` loads a playlist, `N` opens the browser and `Ctrl+F` searches. `Ctrl+F` also works from the playlist view.
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"lyrion",…}' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server lyrion)` takes about 25 s: an image already pulled, then 13 s of server bootstrap. The doctor prints `server lyrion: http://127.0.0.1:<port> songs=7 playlist_id=8; cliamp sees 1 playlists` and `OK`.
- The server is `lmscommunity/lyrionmusicserver:9.1.2` in container `vc-RUN-lyrion`. It serves the fixture library (scripts/make-library): 7 tracks, 3 albums (`Other Album`, `Second Album`, `Verify Album`), 2 artists, and the saved playlist `Verify Playlist` (id `8`) with `Tone 2` and `Chord 1`. `$VC srv $RUN lyrion status` prints the URL.
- For the auth path, use `VC_LYRION_AUTH=password $VC up --server lyrion`. The server then requires `verify` / `verify-lyrion-pass`, which vc writes into the run's `[lyrion]` block.

- **Library, IPC.** `provider.playlists` `{"provider":"lyrion"}` returns `[{"id":"8","name":"Verify Playlist"}]`. `provider.tracks` `{"playlist":"8"}` returns `Tone 2` then `Chord 1`, with `artist`, `album`, `year`, `genre`, `track_number`, `duration_secs: 60` and `path: "lyrion://track/<id>"`. `provider.artists` returns `Other Artist` and `Verify Artist`. `provider.albums` returns the 3 albums with `artist_id` and `year`, and `sorts` `[album, new]`. `provider.album_tracks` `{"album":"<Verify Album id>"}` returns Tone 1-3 in track order.
- **Search, IPC.** Titles (`chord` gives Chord 1 and 2), album names (`Second Album` gives Chord 1 and 2) and artist names (`Other Artist` gives Pulse 1 and 2) all match. A miss returns `{"ok":true}` with no `tracks` key.
- **Pick the source, UI.** Run `$VC keys $RUN Tab`, then `Right` until the screen shows `SRC \[Lyrion\]`, then `Enter`, then `$VC wait-screen $RUN 'lyrion / Playlists'`. The row reads `> Verify Playlist`.
- **Load, UI.** `Enter` on it, then `$VC wait-state $RUN '.total == 2 and .track.title == "Tone 2"'`. The header shows `[Playlist]`, `.state` stays `"stopped"`, and the settings show `SRC [Lyrion] 4/4`.
- **Play.** `Down Enter` plays `Chord 1` (FLAC). `.state` is `"playing"`, `.duration` is `60`, `.seekable` is `true`, `.position` advances, the time reads `00:03 / 01:00`, and the status reads `● Streaming`. `cli -- seek 30` is relative (from about 12 to about 43), and `cli -- next` starts the next row at about 0.
- **Browser.** `N` shows `lyrion / Browse` with `> By Album`, `By Artist` and `By Artist / Album`. `Enter` gives `lyrion / Albums / Sort: By Name  1/3`, listing `Other Album — Other Artist (2023)`, `Second Album — Verify Artist (2025)` and `Verify Album — Verify Artist (2024)`. `s` switches to `Sort: Recently Added`, and `s` again switches back. `Down Down Enter` shows `lyrion / Verify Album / Tracks  1/3`.
- **Browser actions.** `Down Down Enter` on `Tone 3` plays it and appends it; the status reads `Playing: Verify Artist - Tone 3`. `a` appends all 3 tracks without interrupting playback. `R` asks `Replace current queue?`, and `Enter` confirms: `queue.list` is Tone 1-3, and Tone 1 plays.
- **Search, UI.** `C-f`, then `$VC type $RUN pulse`, then `Enter`. The screen shows `── Results  1/2`, then `── Tracks`, then `> Other Artist - Pulse 1`. `Down Enter` plays `Pulse 2` and closes search to `[Playlist]`. `zzznomatch` gives `No results`.
- **Load over IPC.** `provider.load` `{"playlist":"8"}` and `provider.load_album` `{"album":"<id>"}` replace the playlist **and start playing**, unlike `Enter` in the pane.
- **Auth.** With `VC_LYRION_AUTH=password`, the doctor passes, `curl` to `/jsonrpc.js` without credentials gets `401`, and `provider.load` plays. That proves the file download sends the credentials too. Then set a wrong password (`sed -i '' 's/^password = .*/password = "wrong"/'` on the run's `config.toml`, then `$VC restart $RUN`). The doctor fails with `authentication failed (http 401 Unauthorized) — check user and password`, and the pane shows `No playlists in lyrion.` with `ERR: lyrion: <url>: authentication failed …`.
- **Proof.** Keep the saved `lyrion/*` IPC outputs and screens. `vc down` saves `_server-lyrion.log` and removes the container and its anonymous volumes.

## Gotchas

- **Read-only provider.** There are no favorites, no playlist writes and no scrobbling, so there's nothing to verify server-side. The docs also say listening leaves no play count in LMS. That's plausible, since cliamp only downloads files, but it's UNVERIFIED.
- **IPC loads autoplay.** `provider.load` and `provider.load_album` start playback. The pane's `Enter` doesn't.
- **The provider name is lowercase in the UI.** Pane titles read `lyrion / Playlists` and `No playlists in lyrion.`, while `SRC [Lyrion]` and IPC `provider.list` say `Lyrion`. Match regexes case-sensitively against the real text.
- **cliamp bug (as of `f00408b`): `/ LIVE` for stopped server tracks.** `renderTimeStatus` (`ui/model/view.go:534`) shows `LIVE` whenever `track.Stream && !player.Seekable()`. A stopped player is never seekable, so a stopped `lyrion://` row with a 60 s duration reads `00:00 / LIVE`. It turns into `00:03 / 01:00` once playing. This probably affects every HTTP-streamed server provider.
- **`provider.albums` `.total` is the page size, not the library size** (`Total: len(albums)` in `ui/model/ipc_extended.go`). `limit:1` returns `total:1` although there are 3 albums. Page until an empty page instead.
- **Enter in the browser appends.** In an album's track list, `Enter` adds the highlighted track and the rest of the album to the end of the playlist, then plays them. `R` is the one that replaces.
- `Esc` from `[Playlist]` opens the *default* provider pane (Radio), not Lyrion. Use the `SRC` control.
- **Server bootstrap details, in case the script breaks.** LMS drops the connection (an empty reply) while it starts. It caches `playlistdir` on first read, so the script sets the pref and then restarts the container before `playlists new` works; otherwise LMS answers `Bad Lyrion Music Server config`. `/config` and `/playlist` are anonymous volumes, because LMS runs as `squeezeboxserver` and can't write bind-mounted host dirs. An `.m3u` in the music folder is not imported as a saved playlist.
