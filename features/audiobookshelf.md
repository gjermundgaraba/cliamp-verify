# Audiobookshelf

A user points cliamp at a self-hosted Audiobookshelf server. They see books and podcast shows in the provider pane, browse by author or title, and search. They play chapter files and episodes, and cliamp reports the listening position back to the server, so a later load resumes where they stopped.

## Sub-features

- `abs-pane` lists books under `── Audiobooks` (`Author — Title · N tracks · 2m`) and shows under `── Podcasts` in the provider pane.
- `abs-load` loads a book (one track per audio file, in order) or a show (one track per episode, newest first). It doesn't autoplay.
- `abs-play` plays through cliamp's buffered stream pipeline (`● Streaming`). Tracks are seekable, and the playlist advances from file to file.
- `abs-progress` reports the position with `PATCH /api/me/progress/<item>[/<episode>]` at start, about every 15 s, on stop, and at the end. Book positions are on the whole-book timeline. The book is finished only at the end of the last file.
- `abs-resume` on load from the pane puts the cursor on the in-progress file. `Enter` on it starts at the saved offset.
- `abs-browse` opens the `N` overlay, with `By Title`, `By Author` and `By Author / Title`. Authors and podcast hosts are merged.
- `abs-search` uses `Ctrl+F` and matches item titles and authors. It expands each hit into tracks.
- `abs-ipc` covers `provider.playlists`, `tracks`, `search`, `artists`, `artist_albums`, `albums` (with `sort`) and `album_tracks`. `provider.catalog` isn't supported.
- `abs-auth` accepts an API key (`token`) or `user`/`password`, which logs in on first use.

## How to get to it (user POV)

- Config: an `[audiobookshelf]` block with `url` plus `token`, or `user` and `password`. `vc up --server audiobookshelf` writes it into the run's config.
- Provider pane: press `B`, then use `Enter` to load, `N` to browse and `Ctrl+F` to search.
- Terminal: `cliamp remote call provider.<op> --params '{"provider":"audiobookshelf",…}' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --server audiobookshelf)`. The first run pulls the image, and later runs are ready in about 12 s.
- The doctor prints `server audiobookshelf: http://127.0.0.1:PORT user=root password=verify-pass book=<id> show=<id>; cliamp sees 2 playlists` and `OK`.
- The server has the book `Verify Author — Verify Book` (2 × 60 s chapter files, 2022) and the show `Verify Host / Verify Show` (2 × 45 s episodes). The login is local and throwaway, so writes are fine.
- Server-side checks use the root session token: `S=/tmp/vc-$RUN/srv-audiobookshelf; U=http://127.0.0.1:$(cat $S/port); curl -H "Authorization: Bearer $(cat $S/session)" "$U/api/me/progress/$(cat $S/book-id)"`.
- `VC_ABS_AUTH=password $VC up --server audiobookshelf` configures `user`/`password` instead of `token`. The doctor, loading and playback were verified in that mode as well.

- **Pane.** Press `B`, then run `$VC wait-screen $RUN 'Audiobookshelf / Playlists'`. The pane shows `── Audiobooks` with `> Verify Author — Verify Book · 2 tracks · 2m`, then `── Podcasts` with `Verify Show · 2 tracks`.
- **IPC listing.** `provider.playlists` returns `.total` `2`. The ids are `b:<bookId>` (section `Audiobooks`, `track_count` 2, `duration_secs` 120) and `p:<showId>` (section `Podcasts`). `provider.tracks` on `b:<id>` returns `Chapter 1` and `Chapter 2` (artist `Verify Author`, album `Verify Book`, `stream: true`, path `…/api/items/<id>/file/<ino>?token=…`). On `p:<id>` it returns `Episode 2` before `Episode 1`.
- **IPC browse and search.**
  - `provider.artists` returns `Verify Author` and `Verify Host` (id `h:Verify Host`).
  - `artist_albums` for `h:Verify Host` returns `Verify Show`.
  - `albums` returns both titles (the book with `year` 2022). `sort: "recent"` is accepted.
  - `album_tracks` on `b:<id>` returns 2 chapters.
  - `provider.search` with `query` `verify` returns 4 tracks.
- **Load.** Press `Enter` on the book, then run `$VC wait-state $RUN '.total == 2'`. The header shows `[Playlist]`, `.state` is `"stopped"`, and the settings column shows `SRC [Audiobookshelf]`.
- **Play and progress.** Press `Enter` on row 1, then run `$VC wait-state $RUN '.state == "playing"' 30`. `.duration` is `60`, `.seekable` is `true`, and the header reads `00:02 / 01:00  ● Streaming`. Right away the server has `currentTime` about 0.25 and `duration` 120. About 19 s later, `currentTime` is about 15 (the 15 s report).
- **Across files.** Near the end of chapter 1 (for example, `cli -- seek 30` from about 25 s), `.track.title` becomes `Chapter 2`, and the server has `currentTime` `60`, the start of file 2 on the book timeline.
- **Finish.** In chapter 2, run `cli -- seek 50` and wait for `.state != "playing"`. The server has `currentTime` 120, `progress` 1 and `isFinished` true.
- **Stop reports.** Play chapter 2, seek to about 20 s, wait 17 s, then press `s`. The server `currentTime` is about 97, which is 60 + 37. Replaying a finished book sets `isFinished` back to false.
- **Resume.** Press `Escape` to go to the pane, then `Enter` on the book. The cursor (`>`) is on `2. … Chapter 2`. Press `Enter`, then run `$VC wait-state $RUN '.state == "playing"'`. `.track.title` is `Chapter 2` and `.position` is about the saved offset minus 60 (about 38).
- **Podcast.** In the pane, press `Down` then `Enter` on `Verify Show`. The rows are `Episode 2`, then `Episode 1`. Play one, `seek 10`, wait 16 s, then `s`. In `GET /api/me`, `.mediaProgress[]` has an entry for the show with `episodeId` set to Episode 2's id and `currentTime` about 27.
- **Browse.** Press `N` for `By Title`, `By Author` and `By Author / Title`. Under `By Author`, `Enter` lists `Verify Author (1 titles)` and `Verify Host (1 titles)`. `Down` `Enter` goes to `Audiobookshelf / Verify Host / Tracks  1/2` with Episode 2 first, and the help offers `R  Replace queue`.
- **Search.** From the pane, `Ctrl+F`, `$VC type $RUN verify` and `Enter` give `── Results  1/4` with Chapter 1, Chapter 2, Episode 2 and Episode 1 under `── Tracks`.
- **Proof.** Keep the `vc cli --save abs/…` outputs and screens, and the server `progress` JSON printed by curl. `vc down` saves `_server-audiobookshelf.log` and removes the container.

## Gotchas

- **Resume only sticks with `Enter` (cliamp bug, as of `f00408b`).** After a resume load, the cursor is on the in-progress file, but the playlist's current track is still file 1: the header and `.track.title` say `Chapter 1`. `Space` plays Chapter 1 from 0, and cliamp's next report **overwrites the server's saved position** (99.6 → 1.4 in testing). The cause is that `applyTracksResume` (`ui/model/providers.go:180`) sets `plCursor` but not the playlist index.
- **`progress` goes stale (cliamp bug).** Only a report with a duration includes `progress`, and the periodic and stop reports don't send one. `currentTime` stays right, but the server's `progress` stays at its first value (for example 0.002) or 0 until the finishing report. The Audiobookshelf web UI shows a percentage based on that value.
- **API key at rest (cliamp bug).** Stream paths carry `?token=<API key or session token>`. They land in `history.toml` (and `Recently Played`), in the IPC snapshot's `.track.path`, and in saved artifacts. Here the key is throwaway, but on a real server the key is stored in plain text.
- Before playback starts, the header shows `00:00 / LIVE` for a loaded chapter, even though the row shows `1:00`. After play it shows the real duration.
- Search matches item titles and authors, not file or chapter titles: `chapter` finds nothing, and `verify` finds everything.
- `seek` is relative. A late seek that runs past the end of the file moves on to the next file, which looks like a skip.
- Podcasts here come from a local folder (`library/podcasts`), not RSS, so the episodes have no publish date (`year` null).
- A new Audiobookshelf server needs `POST /init` before `/login`. The script also creates an API key with `POST /api/api-keys`, which is what cliamp's `token` uses.
