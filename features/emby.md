# Emby

A user with an Emby server browses its music as a flat album list, drills in by artist, searches tracks, loads an album and streams it through cliamp. cliamp also reports now-playing and scrobbles back to Emby. Runs use a disposable Emby container on the fixture library (`vc up --server emby`), so playback and server-side writes are fine.

## Sub-features

- `emby-auth` logs in with `user` + `password`, or with an API key in `token`.
- `emby-albums` lists every album of the music libraries in the provider pane as `Artist — Album`.
- `emby-load` loads an album into the playlist with `Enter`, and its tracks stream over HTTP.
- `emby-search` searches tracks with `Ctrl+F`. `Enter` on a result appends it and plays it.
- `emby-browse` (`N`) offers By Album (sortable with `s`: name, artist, year), By Artist (all of an artist's tracks), and By Artist / Album.
- `emby-ipc` covers `provider.playlists`, `tracks`, `search`, `artists`, `artist_albums`, `albums`, `album_tracks`, `load` and `load_album` with `provider: "emby"`.
- `emby-report` sends now-playing and scrobble reports to Emby's `/Sessions/Playing*`. These are broken against Emby 4.10 (see Gotchas).
- Unsupported, and rejected cleanly: `provider.catalog` and `provider.favorite`.

## How to get to it (user POV)

- Playlist view: `E` opens the Emby pane (`── Emby / Playlists`). `Enter` loads, `Ctrl+F` searches, `N` browses, and `Esc` goes back.
- Config: an `[emby]` block with `url` plus `user`/`password` or `token` (`docs/emby.md`).
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"emby",…}' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server emby)`. On first use it pulls `emby/embyserver:4.10.0.40` (355 MB). After that it's about 12 s, with Emby ready in about 3 s.
- The doctor prints `server emby: emby 4.10.0.40 at http://127.0.0.1:<port> (login verify / verify-pass, …); cliamp sees 3 playlists` and `OK`.
- The server has 3 albums (Other Album 2023, Verify Album 2024, Second Album 2025, the last one FLAC), 7 tracks, and a server-side `Verify Playlist` (Tone 2, Chord 1) imported from the `.m3u`.
- To query Emby directly: `S=/tmp/vc-$RUN/srv-emby; B=http://127.0.0.1:$(cat $S/port)/emby; T=$(cat $S/token)`, then `curl -H "X-Emby-Token: $T" "$B/…"`.

- **Albums, UI.** Press `E`, then run `$VC wait-screen $RUN 'Emby / Playlists'`. The rows are `> Other Artist — Other Album`, `Verify Artist — Second Album` and `Verify Artist — Verify Album`, sorted by name, with no year suffix (see Gotchas).
- **Albums, IPC.** `provider.playlists` returns `.total` `3`, with ids like `"24"` and names `Artist — Album`. `provider.tracks` with the Verify Album id returns Tone 1-3 with `track_number` 1-3, `duration_secs` `60` and `path` `http://127.0.0.1:<port>/Items/<id>/Download?ApiKey=…`.
- **Load and play.** Highlight Verify Album and press `Enter`, then run `$VC wait-state $RUN '.total == 3 and (.track.path|startswith("http"))'`. The header shows `[Playlist]`, the album name appears as a group header, and it stays stopped. Press `Enter`, then `$VC wait-state $RUN '.state == "playing"' 20`. `.seekable` is `true` and `.duration` is `60`. `Space` pauses (the position freezes) and resumes, and `>` moves to Tone 3. At the end of a track, playback moves on to the next one.
- **FLAC.** `provider.load_album` with the Second Album id replaces the playlist and starts playing `Chord 1`, and `.position` advances.
- **Search.** From the pane, run `$VC keys $RUN C-f`, `$VC type $RUN pulse` and `$VC keys $RUN Enter`. The screen shows `── Results  1/2` with a `── Tracks` section. `Down Enter` appends `Pulse 1` (`.total` +1) and plays it. IPC: `provider.search` `{"query":"chord"}` returns Chord 1 and 2.
- **Browse.** Press `N`, which shows `── Emby / Browse` with `By Album`, `By Artist` and `By Artist / Album`.
  - By Album: `── Emby / Albums / Sort: Alphabetical by Name  1/3`. `s` cycles through `Alphabetical by Artist` and `By Year`.
  - By Artist: `Other Artist (1 albums)` and `Verify Artist (2 albums)`. `Enter` on an artist opens `── Emby / Verify Artist / Tracks  1/5`, and `Enter` on a track appends all 5 and plays the selected one.
  - IPC: `provider.artists` returns 2 with `album_count`. `provider.artist_albums` returns 2. `provider.albums` returns 3, with `sort_types` `name`, `artist` and `year`.
- **IPC load.** `provider.load` with an album id replaces the playlist, and playback starts. The job's snapshot still says `stopped`, so check `vc state` afterwards.
- **API-key auth.** Create a key with `curl -X POST -H "X-Emby-Token: $T" "$B/Auth/Keys?App=vc-verify"`, then read it from `$B/Auth/Keys`. Replace the `user`/`password` lines in `/tmp/vc-$RUN/home/.config/cliamp/config.toml` with `token = "<key>"` and run `$VC restart $RUN`. The doctor passes, `provider.load_album` plays, and the edited block survives the quit.
- **Server-side reporting (currently fails).** While playing, `curl … "$B/Sessions"` should show a session with `NowPlayingItem`, and after half a track, `$B/Users/<user_id>/Items?Recursive=true&IncludeItemTypes=Audio&Fields=UserData` should show `PlayCount` 1. Today neither happens: see Gotchas.
- **Proof.** Run `$VC screen $RUN emby/<label>` and save the IPC outputs. `vc down` also saves `_server-emby.log`.

## Gotchas

- **cliamp bug: reports fail on Emby 4.10.** `ReportNowPlaying` and `ReportScrobble` (`internal/embyapi/client.go:570-600`) post without a `PlaySessionId`. Emby answers `400 Value cannot be null. (Parameter 'key')`, the log shows `now-playing report failed … /Sessions/Playing: http status 400` and `scrobble failed … /Sessions/Playing/Progress: http status 400`, and play counts stay at 0. The same request with `"PlaySessionId":"<any>"` returns `204` and shows the item in `/Sessions`.
- **cliamp bug: no years or track counts from Emby.** `AlbumsByLibrary` (`internal/embyapi/client.go:397`) doesn't request `fields=ProductionYear,ChildCount`, and Emby omits both unless asked. So album rows have no `(Year)` suffix, `year` and `track_count` are missing over IPC, and `By Year` sorting (client-side, `sortAlbums`) is a no-op. The same query with `fields=ProductionYear,ChildCount` returns 2023/2024/2025 and 2/2/3.
- **Server playlists are invisible.** cliamp's Emby "playlists" are albums. The server-side `Verify Playlist` exists (`$B/Playlists/<id>/Items`) but has no path in cliamp.
- **The token is in track URLs.** Stream paths carry `ApiKey=<token>&api_key=<token>`, and they show up in `vc state`, the IPC artifacts and the log. That's harmless for a disposable run, but don't reuse these recipes against a real server without scrubbing.
- **Keys depend on the pane.** After a search or browse action, focus is in `[Provider]` or `[Browse]`, where `s` doesn't stop (in browse, `s` cycles the sort). Stop with `$VC cli $RUN -- stop`.
- Right after loading an album while stopped, the time line reads `00:00 / LIVE`. It shows the real duration once playing.
- Search results aren't sorted (`Pulse 2` before `Pulse 1`). Assert by title, not by position.
- The wizard runs through `/Startup/Configuration`, `/Startup/User` and `/Startup/Complete`, then `/Users/AuthenticateByName` with `X-Emby-Authorization`. The library is added with `/Library/VirtualFolders?collectionType=music&refreshLibrary=true`. None of it needs Emby Premiere. `ready` waits for 7 tracks, years on all albums (they arrive a few seconds after the tracks), and the 2-track imported playlist.
- `vc srv $RUN emby status` prints the URL and the test login. The admin login is `verify` / `verify-pass`, per run and local only.
