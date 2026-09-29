# Play-next queue

A user marks tracks to play next without reordering the playlist, reviews and edits that queue in a manager, and scripts it over IPC. `next` takes queued tracks first, in queue order.

## Sub-features

- `queue-toggle` toggles the highlighted track in the play-next queue with `a`, and the row shows `Q` and `[Qn]`.
- `queue-order` makes `next` play queued tracks first and removes them from the queue as they play.
- `queue-manager` opens the queue manager with `A`: `d` removes, `c` clears and closes the manager, and `Esc` closes it.
- `queue-undo` restores a cleared queue with `Ctrl+Z`.
- `queue-ipc` lists and edits the queue with `playnext.list`, `playnext.remove`, `playnext.move` and `playnext.clear`.
- `queue-append-cli` appends a file to the playlist (not the play-next queue) with `cliamp queue <path>`.

## How to get to it (user POV)

- Playlist view (`[Playlist]`): `a` on a row toggles it, and `A` opens the manager.
- Terminal: `cliamp queue <path>`, and `cliamp remote call playnext.<op> --params '<json>' --wait`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`, nothing playing, and `.play_next_total` absent.

- **Queue a track.** Highlight Tone 3 and press `a`. Run `$VC keys $RUN Down Down a` then `$VC wait-state $RUN '.play_next_total == 1'`. The row reads `> Q  3. Verify Artist - Tone 3 · Verify Album [Q1]`.
- **IPC view.** Run `$VC cli $RUN --save queue/list -- remote call playnext.list --wait`. `.job.result.tracks` has one entry: `Tone 3` with `queue_position` `1` and `index` `2`.
- **Queued plays next.** Start Tone 1, then skip. Run `$VC keys $RUN Up Up Enter` and `$VC wait-state $RUN '.state == "playing" and .track.title == "Tone 1"'`. Then run `$VC keys $RUN '>'` and `$VC wait-state $RUN '.track.title == "Tone 3"'`. The skip went to the queued Tone 3, not Tone 2, and `.play_next_total` is absent again.
- **Manager.** Queue Tone 2 and open the manager. Run `$VC keys $RUN Up a A`, then `$VC wait-screen $RUN '\[Queue\]'`. The list reads `── Queue  1/1` with `>  1. Verify Artist - Tone 2`, and the help bar offers `d  Remove` and `c  Clear`.
- **Clear and undo.** Press `c`. Run `$VC keys $RUN c`, then `$VC wait-screen $RUN 'Cleared queue \(Ctrl\+Z to undo\)'`. The manager closes on its own (`[Playlist]`) and `.play_next_total` is absent. Press `Ctrl+Z` (`$VC keys $RUN C-z`), then `$VC wait-state $RUN '.play_next_total == 1'`, and the Tone 2 row shows `Q` and `[Q1]` again.
- **Append from CLI.** Run `$VC cli $RUN --save queue/cli-append -- queue /tmp/vc-$RUN/music/01-tone-1.mp3`, with exit `0`. `.total` grows from `3` to `4`, and `.play_next_total` is unchanged (still `1` after the undo).
- **Proof.** Run `$VC screen $RUN queue/final` and `$VC cli $RUN --save queue/state -- remote call queue.list --wait`.

## Gotchas

- `c` in the manager clears the queue and closes the manager in one step. Don't follow it with `Esc`, which from the playlist opens the provider pane.
- `.play_next_total` is omitted from the snapshot when the queue is empty, not `0`. Use `(.play_next_total // 0) == 0`.
- `cliamp queue <path>` appends to the live playlist. Despite the name, it doesn't add to the play-next queue.
- Known gap (as of `f00408b`): `cliamp queue` doesn't check the path. `cliamp queue /nonexistent.mp3` exits `0` and adds a row for a missing file.
- `a` also means "append" in some provider and podcast views. Prove the queue toggle from `[Playlist]`.
- `queue.*` IPC operations act on the live playlist and `playnext.*` on the queue. They use separate zero-based indexes.
