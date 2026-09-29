# Speed and mono

A user changes playback speed in 0.25x steps between 0.25x and 2x, and folds stereo to mono, from keys or from `cliamp speed` and `cliamp mono`. Speed audibly changes the playback rate and is saved; mono is a per-session toggle.

## Sub-features

- `speed-keys` changes speed with `]` and `[` in 0.25x steps.
- `speed-rate` makes playback position advance at the chosen rate.
- `speed-cli` sets speed with `cliamp speed <0.25-2.0>`, clamping out-of-range values and reporting the clamped value.
- `speed-persist` saves `speed` to `config.toml` about a second after the last change.
- `mono-toggle` toggles mono with `m` or `cliamp mono [on|off]`, shown as `[M]` after the volume bar.

## How to get to it (user POV)

- Playlist view (`[Playlist]`): `]`/`[` for speed, `m` for mono.
- Focused settings: `Tab` to `SPD`, then `Right`/`Left`.
- Terminal: `cliamp speed <ratio>` and `cliamp mono [on|off]` (no argument toggles).

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`. `.speed` is `1` and `.mono` is `false`.

- **Speed up.** Press `]` twice. Run `$VC keys $RUN ']' ']'` then `$VC wait-state $RUN '.speed == 1.5'`. The settings row reads `SPD [1.5x]`.
- **Rate really changes.** Play and measure. Run `$VC keys $RUN Space` and `$VC wait-state $RUN '.state == "playing" and .position > 1'`. Then read `.position`, sleep 4 s and read it again. The position advances about 6 s in 4 s.
- **Mono.** Press `m`. Run `$VC keys $RUN m` then `$VC wait-state $RUN '.mono == true'`. The volume row ends in `-30dB [M]`.
- **CLI speed and clamp.** Run `$VC cli $RUN --save speed/cli -- speed 0.5`, with stdout `Speed: 0.50x`. Then run `$VC cli $RUN --save speed/clamp -- speed 3`, with stdout `Speed: 2.00x`. `.speed` is `2`.
- **Step down.** Press `[` five times. Run `$VC keys $RUN '[' '[' '[' '[' '['` then `$VC wait-state $RUN '.speed == 0.75'`.
- **CLI mono.** Run `$VC cli $RUN -- mono off`, with stdout `Mono: off`, and `.mono` is `false`. Run `$VC cli $RUN -- mono`, with stdout `Mono: on`.
- **Speed persisted.** Wait for the debounce, then read the config. Run `sleep 2` and `$VC files $RUN config.toml`. It has `speed = 0.75`.
- **Relaunch.** Run `$VC restart $RUN`, then `$VC wait-state $RUN '.speed == 0.75 and .mono == false'`. Speed survives; mono doesn't.
- **Proof.** Run `$VC screen $RUN speed/final` and `$VC save $RUN config.toml speed/config.toml`.

## Gotchas

- Speed is saved on a 1 s debounce. Reading `config.toml` right after a key press shows the previous value.
- Mono isn't saved by `m` or `cliamp mono`. `mono = true` in `config.toml` (or `--mono`) only sets the starting state. Unlike shuffle, repeat and speed, a toggled mono resets on relaunch. That may be intentional; report it only if a change claims otherwise.
- `[` and `]` also shift the synced-lyrics offset while lyrics are open. Prove speed from the plain playlist view.
- Fixture tracks are 120 s. At 2x a track ends in a minute, so measure the rate early in the track.
