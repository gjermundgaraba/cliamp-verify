# Spotify

A signed-in user browses their Spotify library (Your Music, their own and followed playlists, saved albums), loads a playlist into cliamp, and searches Spotify for albums and tracks. Everything here runs against the user's real account through the verification-only sign-in (SKILL.md, Spotify runs).

## Sub-features

- `spot-signin` shows `Sign in to Spotify. Press Enter to continue.` when signed out. Enter opens the browser and shows the authorize URL. The result lands in `spotify_credentials.json`.
- `spot-library` lists the library in the provider pane under the sections `Library` (`Your Music`), `Your playlists`, `Followed playlists` and `Saved albums`, each with a track count.
- `spot-load` loads the highlighted playlist into the cliamp playlist with `Enter`. The header changes to `[Playlist]` and the rows are `spotify:track:<id>`. It doesn't start playback.
- `spot-search` searches Spotify with `Ctrl+F`, then a query and `Enter`, and shows `── Results  1/N` with an `── Albums` section before `── Tracks`.
- `spot-picker` opens the "Add to Playlist" picker with `p` on a track result. It lists `Your Music` and the user's playlists.
- `spot-ipc` covers `provider.list` (entry `spotify`, `searchable`), plus `provider.playlists`, `provider.tracks` and `provider.search`, all with `provider: "spotify"`.
- Unsupported, and rejected cleanly: `provider.albums`, `provider.artists` and `provider.catalog` fail with `provider does not support …`.

## How to get to it (user POV)

- Provider pane: press `S`, or `Esc`/`b` from the playlist and pick Spotify. `Enter` loads, `Ctrl+F` searches, and `Esc` goes back to the playlist.
- Search results: `Enter` plays (for an album, the album), `a` appends, `q` queues next, `p` adds to a Spotify playlist, `f` favorites an album, and `Esc` goes back to the query.
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"spotify",…}' --wait`, and `cliamp spotify reset`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --spotify)`, and the doctor prints `spotify: signed in, playlists reachable` and `OK`. If it says `not signed in yet`, the user has to sign in: press `S` then `Enter`, and the user finishes in the browser. An agent can't do this step.
- Read-only by default. Nothing below starts playback or writes to the library. The steps under "Only on request" do.

- **Library, UI.** Press `S`, then run `$VC wait-screen $RUN 'Spotify / Playlists'`. The pane shows `── Library` with `> Your Music · N tracks`, then `── Your playlists`.
- **Library, IPC.** Run `$VC cli $RUN --save spotify/playlists -- remote call provider.playlists --params '{"provider":"spotify"}' --wait`. The job succeeded. `.playlists[0]` is `{"id":"YOUR MUSIC","name":"Your Music","section":"Library",…}`. Every entry has `section` from the four above and a `track_count`, and `.total` equals the number of entries.
- **Tracks, IPC.** Pick the smallest playlist, e.g. `jq '[.job.result.playlists[]|select(.section=="Your playlists")]|min_by(.track_count)'`. Pass its `id` to `provider.tracks`. `.total` matches `track_count`, and every track has `title`, `artist`, `album`, `duration_secs` and `path` `spotify:track:<id>`. `{"playlist":"YOUR MUSIC","limit":2}` returns 2 tracks with `.total` equal to the Your Music count.
- **Load, UI.** Highlight that playlist and press `Enter`, then run `$VC wait-state $RUN '.total == <track_count>'`. The header shows `[Playlist]`, the settings column shows `SRC [Spotify]`, `.state` is still `"stopped"`, `.track.path` starts with `spotify:track:`, and `.seekable` is `false` while stopped.
- **Search, IPC.** Run `provider.search` with `{"provider":"spotify","query":"<artist>"}`. A page has up to 25 results, all albums first (`spotify:album:`), and `.total` counts albums plus tracks. With `offset` 25, the next page has both kinds. A `limit` below the album count returns only albums.
- **Search, UI.** From the provider pane, run `$VC keys $RUN C-f`, `$VC type $RUN '<artist>'` and `$VC keys $RUN Enter`, then `$VC wait-screen $RUN 'Results +1/'`. The results show `── Albums`, then `── Tracks` further down. Move with `Down` only.
- **Picker, read only.** Highlight a row under `── Tracks` and press `p`, then run `$VC wait-screen $RUN 'Add to Playlist +1/'`. The picker lists the track, then `> Your Music` and the playlists (count = playlists + 1). **Leave with `Escape` only.** `Enter` here adds the track to the user's Spotify playlist.
- **Back out.** `Escape` from the picker returns to `── Results  1/N`, the cursor reset to the top. `Escape` again goes to the query (`Search: <artist>_`), and once more to `[Provider]`.
- **No writes happened.** Run `provider.playlists` again and compare `[.job.result.playlists[]|{id,track_count}]` with the first save. It's identical, and `.state` is still `"stopped"`. The log doesn't record HTTP methods, so grepping it proves nothing.
- **Proof.** Run `$VC screen $RUN spotify/final`, and keep the saved IPC outputs. `vc down` stores the rotated credential and scrubs tokens from the artifacts.

### Only on request (the user must ask in this conversation)

Playback streams on the user's account and takes over their other Spotify devices. Keep it short at `--vol -30`, and stop with `$VC cli $RUN -- stop`, which works from any pane. Writes go only to a new playlist created for the run. Never add to the user's existing playlists.

- **Play.** Load the smallest playlist (see above), then press `Enter` on row 1, and run `$VC wait-state $RUN '.state == "playing"' 60`. `.track.path` is `spotify:track:<id>`, `.duration` is set, `.seekable` is `true`, and `.position` moves about 5 in 5 s. The screen shows `▶ Playing` and `00:05 / 03:53`.
- **Seek, pause, speed.** `$VC cli $RUN -- seek 120` is **relative**, so `.position` grows by about 120. `Space` pauses: `.state` is `"paused"` and `.position` stays frozen over 2 s. `Space` again resumes. `cli -- speed 1.5` makes `.position` advance about 6 in 4 s. Reset with `speed 1`.
- **Next and stop.** `>` moves to row 2, which plays from about 0. `s` in `[Playlist]` stops it.
- **Search `a` on a track (while stopped).** `.total` grows by 1, and playback starts on the appended row.
- **Search `q` on a track (while playing).** The current track keeps playing. `.total` grows by 1, `.play_next_total` is `1`, and the row shows `Q` and `[Q1]`.
- **Search `Enter` on an album.** The album plays right away: `.track.album` is the album title and `.total` grows by the album's track count. Focus returns to `[Provider]`.
- **Create a playlist (write).** On a track result press `p`, then `Up`, which wraps to `> + New Playlist...`. Press `Enter`, then `$VC type $RUN 'cliamp-verify <date>'`, then `Enter`. The search closes into `[Provider]`. `provider.playlists` `.total` grows by 1, and the new entry is private (`"public": false` in `CreatePlaylist`). `provider.tracks` on its `id` returns the one track.
- **Add to that playlist (write).** Open the picker on another track and move to the new playlist. **Check that `> <new name>` is the highlighted row, then press `Enter`.** `provider.tracks` now returns 2, in the order added.
- **No-op writes.** Picker `Enter` on `> Your Music` does nothing, and the picker stays open. `f` on an album result does nothing, because Spotify has no `ToggleFavorite`.
- **Blast radius.** Compare `[.job.result.playlists[]|select(.id != "<new id>")|{id,track_count}]` against a baseline taken before the writes. It must be identical.
- **Undo.** cliamp can't delete playlists. Tell the user the playlist name, and they delete it in the Spotify app.

## Gotchas

- **Sign-in loop (cliamp bug, as of `f00408b`).** If the credential's playback half is valid but its Web API half isn't, `Enter` on `Sign in to Spotify` does nothing. This happens after switching `client_id`, for example. `Authenticate()` returns early because a session exists (`external/spotify/provider.go:123`), the playlist load fails again, and the prompt comes back. Fix: `$VC cli $RUN -- spotify reset` (it removes only the run's copy), then `$VC restart $RUN`, then sign in.
- **A refresh token belongs to its client ID.** Changing `SPOTIFY_CLIENT_ID` or `spotify_client_id` needs a new sign-in. With your own app, the browser does two approvals in one tab.
- **Shared built-in client ID.** Its Web API quota is shared worldwide and often exhausted. The log shows `web api rate-limited … retrying in 24h0m0s`, and IPC jobs wait out the whole `Retry-After`, so a bare `--wait` hangs. The doctor bounds its own check at 20 s. The UI misleadingly shows `Sign in via Spotify, or check SPOTIFY_REFRESH_TOKEN` next to `context deadline exceeded`.
- **Search keys autoplay.** `Enter`, `a` and `q` on search results start playback when nothing is playing (`appendAlbum` and `queueTrackNext` check `!IsPlaying()`). Only `p` (then `Escape`) and the arrows are safe.
- **Keys depend on the pane.** After a search action or a playlist write, focus lands in `[Provider]`, where `s` doesn't stop. Stop with `cli -- stop`, or check the header tag before pressing keys.
- **The pane is stale after writes.** The provider pane doesn't show a new playlist until `Ctrl+R`. Right after creation, `provider.playlists` lists it without `track_count`, and the count appears after the next add.
- On macOS, `seq 1 0` counts down (it prints `1 0`), so a loop of "N Downs" with N=0 presses Down twice. Guard N=0.
- `Space` in the provider pane toggles playback of the current track. Don't use it to "select".
- `provider.favorite` isn't implemented for Spotify (no `ToggleFavorite`). It is untested, though, so don't call it on the real account to find out.
- The credential rotates on every launch. Never run two Spotify runs at once (`spotify.lock` enforces it), and never copy the store by hand.
- Evidence contains the user's playlist and track names. That's fine locally, but don't paste it into anything outward-facing.
