# Playback controls

A user starts, pauses, stops and skips tracks, seeks within a track, and changes volume, either with TUI keys or with `cliamp` subcommands from another terminal. The status line, time line and volume bar reflect every change.

## Sub-features

- `play-toggle` toggles between playing and paused.
- `play-stop` stops playback and clears the position.
- `play-skip` moves to the next or previous track.
- `play-seek` seeks relative to the current position.
- `play-volume` changes the volume in dB.
- `play-cli` does the same operations from `cliamp` subcommands against the running TUI.

## How to get to it (user POV)

- In the playlist view: `Space` play/pause, `s` stop, `>` or `.` next, `<` or `,` previous, `Left`/`Right` seek ∓5 s, `Shift+Left`/`Shift+Right` seek ∓30 s, `+`/`-` volume ±1 dB.
- In another terminal: `cliamp toggle|play|pause|stop|next|prev`, `cliamp seek <relative seconds>`, `cliamp volume <absolute dB>`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)` and `$VC doctor $RUN` reports `OK` with `state":"stopped"` and `Tone 1`.
- The header shows `[Playlist]`.

- **Start playback.** Press Space. Run `$VC keys $RUN Space` then `$VC wait-state $RUN '.state == "playing"'`. The status line reads `▶ Playing` and the time line counts up from `00:00 / 02:00`.
- **Pause.** Press Space again. Run `$VC keys $RUN Space` then `$VC wait-state $RUN '.state == "paused"'`. The status line reads `⏸ Paused` and `.position` stops advancing across two `$VC state` reads.
- **Seek with keys.** Resume and press Right twice. Run `$VC keys $RUN Space Right Right` then `$VC state $RUN '.snapshot.position'`. Position is about 10 s past where it was.
- **Next and previous.** Press `>` then `<`. Run `$VC keys $RUN '>'` then `$VC wait-state $RUN '.track.title == "Tone 2"'`, then `$VC keys $RUN '<'` and `$VC wait-state $RUN '.track.title == "Tone 1"'`. The playlist counter moves between `[2/3]` and `[1/3]`.
- **Volume with keys.** Press `+`. Run `$VC keys $RUN +` then `$VC state $RUN '.snapshot.volume'`. Volume is `-29` and the settings row reads `-29dB`.
- **Stop.** Press `s`. Run `$VC keys $RUN s` then `$VC wait-state $RUN '.state == "stopped"'`. `.position` is null and the status line reads `■ Stopped`.
- **CLI control.** Drive from a second terminal. Run `$VC cli $RUN --save playback/cli-next -- next`, `$VC cli $RUN -- seek 30`, and `$VC cli $RUN -- volume -20`. Each exits `0`. The snapshot shows the next track playing, position about 30 s later, and volume `-20`.
- **Proof.** Capture both views. Run `$VC screen $RUN playback/final` and `$VC cli $RUN --save playback/status -- status --json`. The screen and JSON agree on the track, state and volume.

## Gotchas

- `cliamp volume N` sets an absolute dB value, while `+`/`-` step by 1 dB. `cliamp seek N` is relative.
- `next` from the stopped state starts playback on the next track.
- Seeking while paused or stopped behaves differently from seeking while playing. Resume first when proving seek.
- Position values are float seconds that keep moving while playing. Compare ranges, not exact values.
