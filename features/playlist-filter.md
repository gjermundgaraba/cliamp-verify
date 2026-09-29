# Playlist filter

A user presses `/` in the playlist, types a fuzzy query, sees the matching tracks with a match count, and either plays a match with `Enter` or cancels with `Esc` to get the full playlist back.

## Sub-features

- `filter-open` opens the filter input from the playlist.
- `filter-match` narrows the list with fuzzy, in-order character matching.
- `filter-empty` shows an explicit no-match state.
- `filter-play` plays the highlighted match on `Enter`.
- `filter-cancel` restores the full playlist on `Esc`.

## How to get to it (user POV)

- Press `/` while the playlist has focus (header `[Playlist]`).
- Inside the filter: `Up`/`Down` or `Ctrl+N`/`Ctrl+P` move between results, and `Ctrl+U` clears the query.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`, nothing playing.

- **Open filter.** Press `/`. Run `$VC keys $RUN /` then `$VC wait-screen $RUN '\[Filter\]'`. The header reads `[Filter]` and the help bar shows `Esc  Cancel  Enter  Confirm`.
- **Fuzzy match.** Type a non-contiguous query. Run `$VC type $RUN 'ton3'` then `$VC wait-screen $RUN '1 matches of 3 total'`. Only `3. Verify Artist - Tone 3` is listed.
- **Empty state.** Replace the query. Run `$VC keys $RUN C-u`, `$VC type $RUN 'zzzq'`, then `$VC wait-screen $RUN 'No matches'`. The line reads `0 matches of 3 total`.
- **Cancel.** Press Esc. Run `$VC keys $RUN Escape` then `$VC wait-screen $RUN '\[Playlist\]'`. All three tracks are listed again and nothing started playing (`$VC state $RUN '.snapshot.state'` is `"stopped"`).
- **Play a match.** Filter again and press Enter. Run `$VC keys $RUN /`, `$VC type $RUN 'ton3'`, `$VC keys $RUN Enter`, then `$VC wait-state $RUN '.state == "playing" and .track.title == "Tone 3"'`. The header returns to `[Playlist]` with `>▶  3.` highlighted and the counter at `[3/3]`.
- **Proof.** Run `$VC screen $RUN playlist-filter/playing-match` and `$VC cli $RUN --save playlist-filter/status -- status --json`. Both show `Tone 3` playing.

## Gotchas

- One `Enter` both confirms the filter and plays the highlighted match. There is no separate "apply" step.
- `Esc` from the playlist, as opposed to from the filter, opens the provider pane (`[Provider]`). Send one `Esc` per level and check the mode tag.
- While the filter is open, letter keys are query text. `q` does not quit and `s` does not stop.
