# Jellyfin

A user points cliamp at a Jellyfin server, browses artists, albums and songs, searches, and streams tracks. cliamp reports playback back to the server. Runs use a disposable Jellyfin container seeded with the fixture library (`scripts/servers/jellyfin`), so writes and playback are fine.

## Sub-features

- `jf-auth` logs in with `user` and `password` (the default), or with an API key (`token`, set `VC_JELLYFIN_AUTH=token`).
- `jf-browse` opens with `J` in **By Artist / Album** mode: artist, then albums, then tracks. `N` offers **By Album**, **By Artist** and **By Artist / Album**. `/` filters any level.
- `jf-queue` plays from the browser. `Enter` on a track starts it (added to an empty playlist). `R` asks `Replace current queue?`, and `Enter` replaces the queue with the displayed tracks and starts playing.
- `jf-search` searches tracks with `Ctrl+F`. `Enter` on a result appends it and plays it.
- `jf-stream` streams MP3 and FLAC with duration, seeking and gapless advance.
- `jf-report` reports playback. A track start posts `/Sessions/Playing`. Leaving a track past 50% of its length (natural end, skip, stop) posts progress plus `/Sessions/Playing/Stopped`, which is the scrobble.
- `jf-restore`: with Jellyfin as the start provider and no file arguments, a relaunch restores the last track and its album, stopped. `Enter` resumes from the saved position.
- `jf-ipc` covers `provider.list` (`browse_artists`, `browse_albums`, `searchable`), `provider.playlists` (the albums), `provider.tracks`, `provider.search`, `provider.artists`, `provider.artist_albums`, `provider.albums` (sorts `name`, `artist`, `year`), `provider.album_tracks`, `provider.load` and `provider.load_album`.
- Unsupported, and rejected cleanly: `provider.catalog` (`provider does not support catalog paging`) and `provider.favorite` (`provider does not support favorites`).

## How to get to it (user POV)

- Configure it with `[jellyfin]` `url` plus `user`/`password` or `token` in `config.toml`, or with `cliamp setup`.
- Press `J` from the playlist or provider views. With `--provider jellyfin` (or `provider = "jellyfin"`), cliamp starts in the Jellyfin browser.
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"jellyfin",…}' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server jellyfin)`. It takes about 15-20 s for the container, wizard, library scan and playlist, after the first image pull. Doctor prints `server jellyfin: http://127.0.0.1:<port> user=verify password=verify-pass user_id=…; cliamp sees 3 playlists` and `OK`.
- To look at server-side state, use the state dir `/tmp/vc-$RUN/srv-jellyfin/` (`port`, `session` token, `user_id`) and the container `vc-$RUN-jellyfin`. Set up an API helper like this: `U=http://127.0.0.1:$(cat /tmp/vc-$RUN/srv-jellyfin/port)`, then `A="Authorization: MediaBrowser Client=\"vc\", Device=\"vc\", DeviceId=\"vc-jellyfin\", Version=\"1.0\", Token=\"$(cat /tmp/vc-$RUN/srv-jellyfin/session)\""`.

- **IPC catalog.**
  - `provider.playlists` `{"provider":"jellyfin"}`: `.total` is `3`, and names look like `Verify Artist — Verify Album (2024)`.
  - `provider.tracks` on the Verify Album id: 3 tracks with `artist`, `album`, `year` `2024`, `track_number`, `duration_secs` `60`, `stream` `true`, and path `http://127.0.0.1:<port>/Items/<id>/Download?ApiKey=…`.
  - `provider.search` `{"query":"chord"}` returns Chord 1 and Chord 2.
  - `provider.artists` returns `Other Artist` (1 album) and `Verify Artist` (2).
  - `provider.artist_albums` returns 2 albums.
  - `provider.albums` with `sort` `year` gives Second (2025), Verify (2024), Other (2023). With `name`, it's alphabetical.
- **Browse.** Press `J` and run `$VC wait-screen $RUN 'Jellyfin / Artists +1/2'`. Then `Down Enter` shows `Jellyfin / Verify Artist / Albums  1/2`, and `Down Enter` shows `… / Verify Album / Tracks  1/3` with `1. Verify Artist - Tone 1 … 1:00`.
- **Replace queue.** Press `R` and wait for `Replace current queue?`, then press `Enter`. The header shows `[Playlist]` and `SRC [Jellyfin]`. `.state` is `"playing"` on `Tone 1`, with `.total` `3` and `.seekable` `true`. The screen shows `● Streaming` and `00:03 / 01:00`.
- **Now playing on the server.** `curl -s -H "$A" $U/Sessions | jq '.[] | select(.Client == "cliamp") | .NowPlayingItem.Name'` returns `"Tone 1"` within the first few seconds.
- **Scrobble.** Leave a track past 50%. Either `$VC cli $RUN -- seek 40` and let it end, or skip it after 30 s. `docker logs vc-$RUN-jellyfin 2>&1 | grep "stopped playback of 'Tone 1' at 60000ms (cliamp"`. The activity log (`$U/System/ActivityLog/Entries`) shows `AudioPlaybackStopped | verify has finished playing Verify Artist - Tone 1 on cliamp`. Skipping a track before 50% (for example `>` at 5 s) adds no `stopped playback` line for it.
- **FLAC.** `provider.load` the Second Album id: `.track.title` is `Chord 1` and `.seekable` is `true`, and `.position` advances about 3 in 3 s. `seek 20` moves it by about 20.
- **IPC load.** `provider.load` (album id as `playlist`) and `provider.load_album` (`album`) each replace the playlist with the album's tracks (`.total` `2`) and **start playback, even from stopped**.
- **Search.** From the Jellyfin browser, run `$VC keys $RUN C-f`, `$VC type $RUN pulse` and `$VC keys $RUN Enter`. The screen shows `── Results  1/2` and `── Tracks` with `Other Artist - Pulse 1` and `Pulse 2`. `Down Enter` appends Pulse 2 (`.total` + 1) and plays it.
- **Modes and filter.** In the browser, `N` shows `Jellyfin / Browse` with `By Album`, `By Artist` and `By Artist / Album`. `Enter` on `By Album` shows `Jellyfin / Albums / Sort: Alphabetical by Name  1/3`. `/` then `second` leaves only `Second Album — Verify Artist (2025)`, `Enter` completes the filter, and `Enter` opens `Jellyfin / Second Album / Tracks  1/2`.
- **API-key auth and restore.** Run `RUN=$(VC_JELLYFIN_AUTH=token $VC up --empty --server jellyfin -- --provider jellyfin)`. The config has `token = "…"` and no user, and the screen opens on `[Browse]` `Jellyfin / Artists`. Play a track (for example `Down Enter`, `Enter`, `Down Enter` on Chord 2), then `seek 25`, then `$VC restart $RUN`. After the relaunch, the header shows `[Playlist]`, and `.state` is `"stopped"` on `Chord 2` with `.total` `2` (its album). `resume.json` has `position_sec` about 30 and a `context` array. `Enter` resumes at about that position.
- **Proof.** Run `$VC screen $RUN jf/final`, and keep the saved IPC outputs. `vc down` saves the server log as `_server-jellyfin.log` and removes the container.

## Gotchas

- **Jellyfin counts a play at start.** `POST /Sessions/Playing` alone sets `UserData.PlayCount` to 1 and `Played` to true for audio, so `PlayCount` can't prove cliamp's 50% scrobble. Use the `stopped playback of '<title>' at <ms>ms (cliamp …)` log line or the `AudioPlaybackStopped` activity entry.
- **No progress or pause reports (cliamp gap, as of `c97d21e`).** cliamp posts now-playing only at track start (`nowPlaying` in `ui/model/notifications.go`), and sends progress only just before the stop report. Jellyfin's `/Sessions` drops `NowPlayingItem` mid-track (it was gone by 35 s into a 60 s track), and pause and resume never reach the server.
- **Server playlists aren't shown.** `provider.playlists` returns albums, not Jellyfin playlists. The bootstrapped `Verify Playlist` (`/tmp/vc-$RUN/srv-jellyfin/playlist_id`) exists server-side only. `track_count` is omitted from these album entries.
- **Tokens in plain text.** Track paths embed the access token (`?ApiKey=…`, and in `resume.json` also `&api_key=…`). It shows up in IPC results, `remote state` and `resume.json`, which is fine for these disposable servers. `docs/jellyfin.md` says "no scrobbling/write-back", but cliamp does report playback, so the doc is stale.
- A stopped Jellyfin track shows `00:00 / LIVE` until it plays, even though its duration is known (`1:00` in the list).
- `provider.load` and `provider.load_album` start playback even when stopped. So does `Enter` on a search result or browser track, and `R` then `Enter`.
- While the server starts, it answers API paths with an HTML "server is starting" page and HTTP 200. The script waits for a JSON content type, not just a 200.
- Changing the album sort from the UI is UNVERIFIED. IPC `sort` works.
- Several servers can run at once. Each run gets a free port, so never hard-code 8096 or a port seen in another run.
