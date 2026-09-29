# EQ

A user shapes the sound with the 10-band EQ: cycling named presets with `e`, setting a preset or a single band from `cliamp eq`, and getting the result back on the next launch. The settings pane shows the preset name and the ten gains.

## Sub-features

- `eq-cycle` cycles presets with `e`, starting from `Custom`.
- `eq-preset-cli` sets a named preset with `cliamp eq <preset>`.
- `eq-band-cli` sets one band with `cliamp eq --band N <dB>`, which switches the preset to `Custom`.
- `eq-persist` saves `eq_preset` and `eq` to `config.toml`, and the next launch uses them.

## How to get to it (user POV)

- Playlist view (`[Playlist]`): `e` cycles presets.
- Focused settings: `Tab` to `EQ`, `Left`/`Right` to select a band, `Up`/`Down` to adjust it, `e` to cycle presets.
- Terminal: `cliamp eq <preset>` (for example `Flat`, `Rock`, `Pop`, `Jazz`) and `cliamp eq --band N <dB>`. `N` is zero-based (0-9), and gains range from -12 to +12 dB.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`. The fresh config gives `eq_preset` `Custom` with all bands `0`.

- **Cycle presets.** Press `e` twice. Run `$VC keys $RUN e`, then `$VC wait-state $RUN '.eq_preset == "Flat"'`, then `$VC keys $RUN e` and `$VC wait-state $RUN '.eq_preset == "Rock"'`. `.eq_bands` is `[5,4,2,-1,-2,2,4,5,5,5]` and the settings row reads `EQ  [Rock]`.
- **Preset from CLI.** Run `$VC cli $RUN --save eq/jazz -- eq Jazz`. Stdout `EQ: Jazz`, exit `0`. `.eq_bands` is `[3,4,2,1,-1,-1,1,2,3,4]`.
- **Band from CLI.** Run `$VC cli $RUN --save eq/band -- eq --band 1 6`. Stdout `EQ band 1: 6.0 dB (preset: Custom)`. `.eq_preset` is `Custom`, the *second* value of `.eq_bands` is `6`, and the settings grid shows `+3  +6  +2  +1  -1`.
- **Band out of range.** Run `$VC cli $RUN -- eq --band 10 3`. Exit `1` with `job failed (invalid_params): invalid parameters`, and `.eq_bands` is unchanged.
- **Persisted.** Wait for the debounce, then read the config. Run `sleep 2` and `$VC files $RUN config.toml`. It has `eq_preset = "Custom"` and `eq = [3, 6, 2, 1, -1, -1, 1, 2, 3, 4]`.
- **Survives relaunch.** Run `$VC restart $RUN`, then `$VC wait-state $RUN '.eq_preset == "Custom" and .eq_bands[1] == 6'`.
- **Proof.** Run `$VC screen $RUN eq/settings` and `$VC save $RUN config.toml eq/config.toml`.

## Gotchas

- Band numbers are zero-based: `--band 1` is the 180 Hz band, the second column.
- Known bug (as of `f00408b`): `cliamp eq <unknown>` is accepted. `eq list` or `eq Bogus` exits `0` and prints `EQ: Bogus`. The pane shows `EQ  [Bogus]` and the name is saved as `eq_preset`. After a relaunch, cliamp ignores the saved `eq` curve and plays flat. Don't use `eq list` to discover presets, since it sets a preset named `list`.
- Known bug (as of `f00408b`): out-of-range gains are clamped to ±12, but the CLI echoes the requested value. `eq --band 1 99` prints `99.0 dB` while `.eq_bands[1]` is `12`. Assert on the snapshot, not on the CLI output.
- EQ changes are saved on a 1 s debounce, like speed. `config.toml` may not exist or may show the previous curve right after a change.
- The `e` cycle includes the saved `Custom` curve. Starting from a fresh config, the first `e` lands on `Flat`.
