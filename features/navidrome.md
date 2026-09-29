# Navidrome

A user connects cliamp to a Navidrome (Subsonic) server, browses its playlists, albums and artists, searches it, and streams tracks; plays are reported back to the server. `vc up --server navidrome` starts a disposable Navidrome (`deluan/navidrome:0.64.2`) on the fixture library, so playback and server-side writes are allowed.

## Sub-features

- `nd-pane` lists server playlists in the provider pane (`── Navidrome / Playlists`, `> Verify Playlist · 2 tracks`). `Enter` loads the playlist without playing it. `Ctrl+R` re-fetches from the server.
- `nd-browser` opens the full-screen browser with `N` from the Navidrome pane: `By Album`, `By Artist`, `By Artist / Album`, drill into tracks, and `/` filters.
- `nd-sort` cycles the album sort with `s` in the album list: Alphabetical by Name → by Artist → Newest → Recently Played → Most Played → Starred → By Year → By Genre. It is saved as `browse_sort` in `[navidrome]`.
- `nd-tracklist` covers the browser track list: `Enter` plays the highlighted track now and enqueues the rest of the list after it, `a` appends all, `q` queues next, and `R` asks `Replace current queue?`, then `Enter` replaces and plays.
- `nd-search` searches with `Ctrl+F` from the pane. Results show under `── Tracks`, and `Enter` plays one immediately.
- `nd-stream` streams through `/rest/stream`: `● Streaming`, seekable, with a known duration.
- `nd-scrobble` reports now-playing (`getNowPlaying` lists player `cliamp`) and scrobbles about halfway through a track (server `playCount` 1, the album shows under `recent`).
- `nd-ipc` covers `provider.list` (`browse_artists` and `browse_albums` are true), `provider.playlists`, `tracks`, `search`, `artists`, `artist_albums`, `albums` (with `sort`), `album_tracks`, `load` and `load_album`.
- Not supported, and rejected cleanly: `provider.catalog` (`provider does not support catalog paging`) and `provider.favorite` (`provider does not support favorites`). `n` on a track is a *local* favorite (`favorites.toml`). It isn't a server star.

## How to get to it (user POV)

- Provider pane: from `[Playlist]` press `Esc` (the run starts on Radio). Then `Tab` until `SRC ▸ [Radio] 1/4`, `Right` ×3 to `SRC ▸ [Navidrome] 4/4`, and `Enter`.
- Browser: `N` from the Navidrome pane (or from `[Playlist]` when Navidrome is the active source).
- Config: `[navidrome]` with `url`, `user`, `password`, and optionally `format`, `browse_sort` and `scrobble = false`. The `NAVIDROME_URL`, `NAVIDROME_USER` and `NAVIDROME_PASS` env vars are used only when the config block is absent.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server navidrome)` (macOS: `env -u GOROOT`). It takes about 5 s after the build. The doctor prints `server navidrome: url=http://127.0.0.1:<port> user=verify password=vc-<hex>; cliamp sees 1 playlists` and `OK`.
- The server has 7 songs in 3 albums by 2 artists (see `scripts/make-library`), plus `Verify Playlist` (Tone 2, Chord 1), imported from the `.m3u` and owned by `verify`.
- To check server-side, run `$VC srv $RUN navidrome status` for the url, user and password, and call Subsonic with them: `curl "$url/rest/<endpoint>?u=verify&p=$pass&v=1.16.1&c=vc&f=json"`.

- **IPC reads.** Run `$VC cli $RUN --save nd/playlists -- remote call provider.playlists --params '{"provider":"navidrome"}' --wait`. `.playlists` is `[{"id":…,"name":"Verify Playlist","track_count":2}]`. `provider.tracks` with that `id` returns Tone 2 and Chord 1, with `year`, `genre`, `track_number`, `duration_secs` 60, and `path` `http://127.0.0.1:<port>/rest/stream?…`. `provider.search` with `{"query":"tone"}` returns 3 tracks. `provider.artists` returns `Other Artist` (1 album) and `Verify Artist` (2). `artist_albums` for Verify Artist returns Verify Album and Second Album, and `album_tracks` for Verify Album returns Tone 1-3. `provider.albums` returns 3 albums, each with `year`, `genre` and `track_count`, plus the 8 `sorts`.
- **Pane.** Switch to Navidrome (see above), then run `$VC wait-screen $RUN 'Navidrome / Playlists'`. The pane shows `> Verify Playlist · 2 tracks`. `Enter` loads it: `[Playlist]`, `.total` 2, `.state` still `"stopped"`.
- **Refresh.** Create a playlist server-side (`createPlaylist?name=Server%20Made&songId=<id>`), then press `Ctrl+R` in the pane. `Server Made · 1 tracks` appears, and the cursor stays on the row it was on. `provider.playlists` already lists it without the refresh.
- **Browser.** From the pane press `N`, then check `wait-screen 'Navidrome / Browse'`, where the rows are `> By Album`, `By Artist` and `By Artist / Album`. `Enter` opens `── Navidrome / Albums / Sort: Alphabetical by Name  1/3` with `Other Album — Other Artist (2023)`. `Enter` again opens `── Navidrome / Other Album / Tracks  1/2`. `By Artist` lists `Other Artist (1 albums)` and `Verify Artist (2 albums)`, and Verify Artist opens a single 5-track list (Tone 1-3, Chord 1-2). `/` then `chord` filters that list to the 2 Chord rows. `Escape` clears the filter.
- **Sort.** In the album list press `s` repeatedly and read `Sort: …` in the header. After a server-side `star?albumId=<Second Album>`, `Starred` shows `1/1  > Second Album`. `Recently Played` and `Most Played` show only albums that were scrobbled. `browse_sort` in `$VC files $RUN config.toml` follows the cycle.
- **Track list actions.** Run these on `Other Album` tracks with the playlist non-empty.
  - `a` appends both tracks, so `.total` grows by 2. If stopped, it plays playlist row 1, not the appended rows.
  - `Enter` on `Pulse 2` makes it `.track.title` right away and appends it (interrupting what played).
  - `R` shows `Replace current queue?`, and `Enter` confirms: `.total` becomes 2, `Pulse 1` is playing, and the header returns to `[Playlist]`.
- **Search.** From the pane, run `$VC keys $RUN C-f`, `$VC type $RUN pulse` and `$VC keys $RUN Enter`. The screen shows `── Results  1/2`, then `── Tracks` with `Other Artist - Pulse 1` and `Pulse 2`. `Enter` on a result plays it immediately and appends it (`.total` +1).
- **Playback.** Press `Enter` on a loaded row. `.state` is `"playing"`, `.seekable` is `true` and `.duration` is `60`, and the screen shows `00:02 / 01:00   ● Streaming`. `cli -- seek 30` is relative (+30). `Space` pauses, and the position freezes.
- **Now playing and scrobble.** While playing, `getNowPlaying` lists `{"title":…,"username":"verify","player":"cliamp"}`. Let a 60 s track pass its midpoint, then check `getAlbum?id=<album>`: that song has `playCount` 1 and `played` set, `getAlbumList2?type=recent` lists the album, and `provider.albums` with `sort:"recent"` agrees.
- **IPC load.** `provider.load` with `{"playlist":<id>}` and `provider.load_album` with `{"album":<id>}` replace the playlist and **start playback**. The reply's snapshot may still say `stopped`, so assert with `wait-state '.state=="playing"'`.
- **Proof.** Keep the `nd/*` saves. `vc down` saves the server log as `_server-navidrome.log` and removes the container.

## Gotchas

- **cliamp bug, as of `c97d21e`: `By Year` and `By Genre` sorts fail.** The UI shows `ERR: Album load failed: navidrome: missing parameter: 'fromYear' (code 10)`, or `'genre'`, and `No albums found.`, and IPC `provider.albums` with `sort:"byYear"` or `"byGenre"` fails the same way. `AlbumList` (`external/navidrome/client.go:400`) sends only `type`, `offset` and `size`, while Subsonic `getAlbumList2` needs `fromYear`/`toYear` or `genre`.
- **cliamp: stream URLs carry the Subsonic auth token.** Track `path`s include `t=<md5(password+salt)>&s=<salt>&u=<user>`, a replayable credential. They appear in IPC output (`provider.tracks`, `provider.load`, snapshots) and are persisted in `favorites.toml` and `history.toml`. That's harmless with the disposable server here, but don't paste evidence from a real server.
- **Docs mismatch (`docs/navidrome.md`).**
  - The docs say pane `Enter` "starts playback", but it only loads. IPC `provider.load` does autoplay.
  - They say browser track-list `Enter` "appends", but it plays immediately and enqueues the rest.
  - They say `N` opens the Navidrome browser "at any time". It opens the browser of the *active* provider (Radio at startup) or the selected track's artist, so switch the source to Navidrome first.
  - They say By Artist is "grouped by album with separator headers", but no headers were shown. The code has a `ctrl+h` album-header toggle (UNVERIFIED).
- A stopped stream track shows `00:00 / LIVE` in the header even though `.duration` is known. It changes to `00:02 / 01:00` once playing.
- `n` (Favorite track) only writes the local `favorites.toml` (`♥︎` in the row and `[♥︎ 1]` in the header). Nothing is starred on the server, and `getStarred2` stays empty.
- The run starts with `SRC [Radio]`, and `Esc` from `[Playlist]` opens the Radio pane (it needs the network for its catalog). Loading Navidrome content over IPC doesn't switch `SRC`.
- Scrobbles are best-effort. `scrobble()` ignores the response status, so check the server rather than cliamp's log. `scrobble = false` is UNVERIFIED.
- The server has no periodic scans (`ND_SCANSCHEDULE=0`) and no external services. To pick up a changed library, call `startScan?fullScan=true` and wait for `getScanStatus` `.scanning == false`.
