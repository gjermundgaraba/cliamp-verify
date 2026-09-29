# Shuffle and repeat

A user toggles shuffle and cycles repeat (Off, All, One) from TUI keys or from `cliamp shuffle` / `cliamp repeat`. The settings pane shows the current mode, and the choice is remembered in `config.toml` for the next launch.

## Sub-features

- `mode-shuffle-key` toggles shuffle with `z`.
- `mode-repeat-key` cycles repeat with `r`.
- `mode-cli` sets shuffle and repeat with subcommands.
- `mode-persist` writes `shuffle` and `repeat` to `config.toml`, where the next launch picks them up.

## How to get to it (user POV)

- In the playlist view: `z` toggles shuffle, and `r` cycles Off → All → One.
- Focused settings: `Tab` to `SHF`/`RPT`, then `Enter` or the arrow keys.
- In a terminal: `cliamp shuffle [on|off|toggle]` and `cliamp repeat [off|all|one|cycle]`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up)`, doctor `OK`, header `[Playlist]`, and no `config.toml` in `$VC files $RUN`.

- **Toggle shuffle.** Press `z`. Run `$VC keys $RUN z` then `$VC wait-state $RUN '.shuffle == true'`. The settings row reads `SHF [On]`.
- **Cycle repeat.** Press `r`. Run `$VC keys $RUN r` then `$VC wait-state $RUN '.repeat == "All"'`. The settings row reads `RPT [All]`.
- **Persisted.** Read the config. Run `$VC files $RUN config.toml`. It contains `shuffle = true` and `repeat = "All"`.
- **CLI set.** Run `$VC cli $RUN --save shuffle-repeat/cli-shuffle -- shuffle off` (stdout `Shuffle: off`) and `$VC cli $RUN --save shuffle-repeat/cli-repeat -- repeat one` (stdout `Repeat: One`). The snapshot shows `shuffle:false, repeat:"One"`, the screen shows `SHF [Off]` and `RPT [One]`, and `config.toml` is updated to match.
- **Survives relaunch.** Quit and relaunch cliamp against the same config dir. Run `$VC restart $RUN` (doctor `OK`), then `$VC wait-state $RUN '.shuffle == false and .repeat == "One"'`. The fresh process shows `SHF [Off]` and `RPT [One]` without any launch flags.
- **Proof.** Run `$VC screen $RUN shuffle-repeat/settings` and `$VC save $RUN config.toml shuffle-repeat/config.toml`.

## Gotchas

- `r` also retries lyrics while lyrics are open. Prove it from the plain playlist view.
- `z` and `r` do nothing in the provider pane. Check for `[Playlist]` first.
- CLI `--shuffle` / `--repeat` launch flags override the config for that session only and are not saved.
- `config.toml` is written only when a persisted setting changes (and theme on quit). Its absence on a fresh run is expected.
