# Plex

A user points cliamp at a Plex Media Server and browses its audio playlists and music albums. They load one into the cliamp playlist, stream the tracks (MP3 and FLAC, seekable), and search the library. Verified against a disposable, **unclaimed** PMS in a container. No plex.tv account is involved at any point.

## Sub-features

- `plex-list` shows the provider pane (`Plex / Playlists`) with `── Playlists` (`<name> · N tracks · Nm`) and `── Albums` (`Artist — Album (Year)`, sorted by artist and album).
- `plex-load` loads the highlighted playlist or album with `Enter`. The header changes to `[Playlist]` and the settings column shows `SRC [Plex]`. Nothing plays yet.
- `plex-play` streams direct file URLs (`<url>/library/parts/…/file.<ext>?X-Plex-Token=…`). `.seekable` is `true`, and FLAC plays too.
- `plex-search` searches the library with `Ctrl+F` in the pane, or with `provider.search`. **Broken**: it always returns nothing (see Gotchas).
- `plex-ipc` covers `provider.list` (`{"key":"plex","searchable":true}`), plus `provider.playlists`, `provider.tracks` and `provider.load`. `provider.albums`, `provider.artists` and `provider.catalog` fail cleanly with `provider does not support …`.
- By design there's no write-back and no scrobbling. After cliamp plays tracks, PMS shows no `viewCount` and an empty history.

## How to get to it (user POV)

- From `[Playlist]`, press `P`. It also works in the provider browser (`Esc`, then pick Plex). `Enter` loads, `Ctrl+F` searches, `Esc` goes back to the playlist, and `Ctrl+R` refreshes.
- Config: `[plex]` with `url` and `token`, and optionally `libraries = ["Music"]`.
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"plex",…}' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server plex)` (on macOS, `env -u GOROOT $VC up …`). The doctor prints `server plex: http://127.0.0.1:<port> unclaimed PMS 1.43.4…, no login (allowedNetworks), token ignored; cliamp sees 4 playlists` and `OK`.
- The server has one library, `Music` (section 1), with the 7 fixture tracks and 3 albums, plus the audio playlist `Verify Playlist` (Tone 2, Chord 1) created through the API. It's ready in about 25-60 s.

- **List, UI.** Press `P`, then `$VC wait-screen $RUN 'Verify Playlist' 15`. You'll see `> Verify Playlist · 2 tracks · 2m` under `── Playlists`, then `Other Artist — Other Album (2023)`, `Verify Artist — Second Album (2025)` and `Verify Artist — Verify Album (2024)` under `── Albums`.
- **List, IPC.** `provider.playlists` with `{"provider":"plex"}` returns `.total` `4`. The playlist has `id` `pl:<ratingKey>`, `section` `Playlists`, `track_count` `2` and `duration_secs` `120`. The albums have their bare ratingKey as `id`, `section` `Albums`, and no `track_count`.
- **Tracks, IPC.** `provider.tracks` with `{"provider":"plex","playlist":"pl:<key>"}` returns `.total` `2`: `Tone 2` (…`file.mp3`) and `Chord 1` (…`file.flac`), with `duration_secs` `60` and a `track_number`. An album `id` returns its tracks in order (`Tone 1..3` for Verify Album).
- **Load, UI.** `Enter` on `Verify Playlist`, then `$VC wait-state $RUN '.total == 2'`. The header shows `[Playlist]`, the rows are `1. Verify Artist - Tone 2 · Verify Album  1:00` and `2. … Chord 1 · Second Album`, and `SRC [Plex]`. `.state` stays `"stopped"`.
- **Load an album, UI.** `Esc` to the pane. Press `Down` three times, one key at a time, checking that the `>` row is `Verify Artist — Verify Album (2024)`, then `Enter`. `.total` is `3` and `.track.album` is `"Verify Album"`.
- **Play.** `Enter` on row 1, then `$VC wait-state $RUN '.state == "playing"' 20`. `.duration` is `60`, `.seekable` is `true`, and `.position` moves about 4 in 4 s. `cli -- seek 30` is relative, so the position grows by about 30. `>` goes to `Chord 1` (the FLAC), which plays, seekable, from about 0. `s` stops.
- **Load over IPC.** `provider.load` with `{"provider":"plex","playlist":"pl:<key>"}` returns the tracks, `.total` becomes `2`, **and playback starts** (see Gotchas).
- **No scrobbling.** Run `curl -s -H 'Accept: application/json' "$URL/library/sections/1/all?type=10" | jq '[.MediaContainer.Metadata[].viewCount]'` after playing. It shows all `null`, and `$URL/status/sessions/history/all` has `size` `0`. `$URL` comes from the `[plex]` block in `vc files $RUN config.toml`.
- **Search (currently fails).** `Ctrl+F` in the pane, `$VC type $RUN chord`, `Enter`. It shows `── Results` / `No results`. `provider.search` with `{"provider":"plex","query":"chord"}` succeeds, but with no `tracks`. The server itself returns `Chord 1` and `Chord 2` for the same query.
- **Proof.** `$VC screen $RUN plex/final`, the saved IPC outputs, and `_server-plex.log` (the PMS log, saved by `vc down`).

## Gotchas

- **cliamp bug (as of `c97d21e`): Plex search always returns nothing on current PMS.** `/library/search?query=…&type=10` on PMS 1.43 nests the hits as `MediaContainer.SearchResult[].Metadata`, but `external/plex/client.go` (`Search`) reads only `MediaContainer.Metadata`. The unit test (`TestSearch_SendsCorrectParams`) serves the old shape with an empty list, so it passes. `/library/sections/<key>/search?type=10&query=…` still returns a flat `Metadata` list.
- **`provider.load` autoplays.** Unlike `Enter` in the pane, it starts playback. Stop with `cli -- stop` if the recipe needs silence.
- **Track years are missing.** Tracks have no `year` (`null`), although the albums have one. cliamp doesn't map the track's `parentYear`.
- **No account, by design.** The server is unclaimed, and `ALLOWED_NETWORKS=0.0.0.0/0` lets any client in without a token. It's safe because the port is published on `127.0.0.1` only. PMS then ignores `X-Plex-Token` entirely. Any non-empty value works, and cliamp gets `vc-unclaimed-no-token-needed`, since `[plex]` is ignored without a token. From macOS, PMS sees clients as the OrbStack gateway (`192.168.215.1`, "Subnet").
- **Token-related behaviour is untestable here.** A wrong or expired token can't be tested, because allowedNetworks bypasses auth. Neither can plex.tv sign-in or remote `plex.direct` URLs.
- **Startup time varies.** The container sits in `startState="startingPlugins"` for 20 s to over 2 minutes (it contacts plex.tv on first start). The script waits up to 240 s. Creating a library before startup finishes returns `400 the server is still starting up`.
- **No `.m3u` import.** Plex doesn't import `.m3u` files from the library folder, so the script creates `Verify Playlist` through `POST /playlists` with a `server://<machineId>/com.plexapp.plugins.library/library/metadata/<keys>` URI.
- The music agent (`tv.plex.agents.music`) may look up online metadata. The fixture titles haven't changed so far, but assert tags you control (title, album, track number), not artwork or bios.
- Provider pane keys can be lost if they're sent right after `Esc`. Send `Down` one at a time and check the `>` row before `Enter`.
