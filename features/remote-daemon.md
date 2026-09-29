# Remote control and daemon

A user runs cliamp headless with `--daemon` (or alongside the TUI) and controls it from other processes: `cliamp status`, the named playback subcommands, and the V2 IPC client `cliamp remote state|call|events|capabilities`. UI-only operations fail cleanly in headless mode.

## Sub-features

- `ipc-daemon` starts headless with no TUI and serves IPC on the config-dir socket.
- `ipc-status` reports state through `cliamp status` and `status --json`.
- `ipc-remote-call` submits V2 operations and returns job results.
- `ipc-events` streams retained `runtime.state` plus `runtime.job` events.
- `ipc-ui-only` rejects `theme` in daemon mode with `unknown_operation`.

## How to get to it (user POV)

- Launch: `cliamp --daemon [--auto-play] [paths…]`. It prints `cliamp: running headless (socket: …/cliamp.sock)` and stops on `SIGINT`/`SIGTERM`.
- Control: `cliamp play|pause|toggle|stop|next|prev|seek|volume|status`.
- V2: `cliamp remote state`, `cliamp remote capabilities`, `cliamp remote call <op> --params '<json>' --wait`, and `cliamp remote events <topics…>`.

## Driving it with vc

Preconditions:

- `RUN=$($VC up --daemon)`, and doctor `OK` reports `mode=daemon`, `"state":"stopped"`, `"total":3`.

- **Headless banner.** Look at the daemon's terminal. Run `$VC screen $RUN ipc/banner`. It shows `cliamp: running headless (socket: /tmp/vc-RUN/home/.config/cliamp/cliamp.sock)` and no TUI.
- **Play and status.** Run `$VC cli $RUN --save ipc/play -- play`, then `$VC wait-state $RUN '.state == "playing"'`, then `$VC cli $RUN --save ipc/status -- status --json`. Exit code `0`, and the JSON has `"state":"playing"` with `track.title` `Tone 1`.
- **Relative seek.** Run `$VC cli $RUN -- seek 10`. `.position` goes up by about 10 s.
- **Remote call.** Run `$VC cli $RUN --save ipc/queue-list -- remote call queue.list --wait`. The response has `ok:true`, and `.job.result.tracks` lists the three fixtures.
- **Event stream.** Subscribe, then trigger a change from another client. Run `$VC events $RUN 3 ipc/events runtime.state runtime.job & sleep 0.5; $VC cli $RUN -- next; wait`. The saved stdout starts with a retained `runtime.state`, then a `runtime.state` with `Tone 2` playing, then a `runtime.job` whose `operation` is `next` and `state` is `succeeded`.
- **UI-only rejection.** Run `$VC cli $RUN --save ipc/theme -- theme foo`. Exit code `1` and stderr `remote operation failed (unknown_operation): unknown operation`.
- **Graceful stop.** Run `$VC down $RUN`. `_exit.txt` reads `pane_dead=1 exit_status=0`.

## Gotchas

- The daemon snapshot has `track: null` until playback starts. The TUI reports track 1 while stopped.
- The daemon does not load Lua plugins and does not preload for gapless playback.
- `remote events` never exits by itself. Use `$VC events`, which bounds it and kills only its own subscriber, not `$VC cli`.
- Jobs are process-local. A job ID from before `restart` returns `not_found`.
- The same recipes work against a TUI run (`$VC up`). There, `theme` and `vis` succeed and change the screen.
