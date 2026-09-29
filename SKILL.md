---
name: verify-cliamp
description: "Drive a real, isolated cliamp instance (the Bubbletea TUI in a private tmux server, or the --daemon headless mode) the way a user does, through keys, CLI subcommands, and IPC V2, and capture evidence. Use it to prove a UI, keybinding, playback, playlist, IPC, or daemon change works in the running app, not just in unit tests."
---

# Verify cliamp

cliamp's user surfaces:
- **Primary:** the TUI, which you drive by keystrokes.
- **Secondary:** the `cliamp <subcommand>` IPC clients and `cliamp --daemon`.

Every verification run gets its own:
- binary, built from the cliamp checkout you run it in (any worktree)
- `HOME` and config dir
- IPC socket
- tone fixtures
- private tmux server (`tmux -L vc-<RUN>`)

The helper `scripts/vc` owns all of it. Always go through it: it is the only thing that keeps a run off the user's real `~/.config/cliamp`.

```sh
VC=$SKILL/scripts/vc   # SKILL is this skill's directory; run from the cliamp checkout's root
$VC help
```

The skill lives outside the cliamp repo (installed at `~/.agents/skills/verify-cliamp`). `vc up` builds the checkout it runs in, so the same install serves every worktree. The other commands work from anywhere.

## Isolation rules (read first)

- **Never run a bare `cliamp` or `go run .` to verify.** The user's shell sets `XDG_CONFIG_HOME`, which beats `HOME`. A bare launch reads and writes the real config, favorites, history, Spotify credentials, and socket. The TUI rewrites `config.toml` on every quit. Use `$VC cli RUN -- ...` for every client call.
- One cliamp per config dir: a second instance cannot bind the socket. Runs are isolated from each other and from the user's instance, so parallel runs are fine.
- Audio really plays through the default output device, at `--vol -30`. On macOS the instance also registers with Now Playing, so hardware media keys may reach it while it runs.
- Startup reaches the network (radio catalog). Local-file features do not need it.

## Launch

```sh
RUN=$($VC up)                        # TUI, 120x40, playlist = 3 tone fixtures, stopped
RUN=$($VC up --daemon)               # headless daemon, same fixtures, no TUI
RUN=$($VC up --size 40x10)           # layout checks (minimal layout; below 40x10 only a resize notice)
RUN=$($VC up --empty -- --playlist "X")   # no fixture dir; extra args go to cliamp
RUN=$($VC up --null-audio)           # Linux: force the per-run PulseAudio null sink (automatic without sound)
RUN=$($VC up --spotify)              # adds [spotify] and the verification-only Spotify sign-in (see below)
RUN=$($VC up --server navidrome)     # plus a disposable media server on the fixture library (see below); repeatable, once per server
```

`up` does the following:
1. Builds `./` into `/tmp/vc-RUN/cliamp` with `git describe` as the version.
2. Generates `/tmp/vc-RUN/music/0{1,2,3}-tone-{1,2,3}.mp3`. These are 120 s sines tagged `Verify Artist - Tone N · Verify Album`, track 1-3.
3. Starts cliamp in tmux session `app`.
4. Waits up to 15 s for IPC `state.get` to answer, then prints `RUN` on stdout and runs doctor on stderr.

Ready means the doctor ends with `doctor: OK`.

For short checks there is nothing long-lived to keep: `up`, drive, `down`.

`$VC restart $RUN` quits cliamp with Ctrl+C and relaunches the same command against the same config dir. Use it to prove state that must survive a restart, such as `config.toml`, `resume.json` or playlists. It does not rebuild.

A code change during a run makes the binary stale (doctor fails). Run `down` then `up` again to rebuild.

Requires `go`, `tmux`, `ffmpeg`, `jq`, `shasum`.

On Linux the build also needs the codec and ALSA headers that CI installs, and a headless box needs PulseAudio for its null sink. The one package list is [`clankerbox-profile/files/debian-packages`](clankerbox-profile/files/debian-packages). The clankerbox profile installs it too. On Debian/Ubuntu:

```sh
apt-get install --no-install-recommends $(cat $SKILL/clankerbox-profile/files/debian-packages)
```

The build needs Go 1.21 or newer, which then downloads the version `go.mod` asks for. Ubuntu 24.04+ and Debian 13+ ship that as `golang-go`. On older releases, install Go from go.dev instead. On a fresh box, the first `vc up` downloads the toolchain and modules and does a cold build, about 1.5 minutes. Later builds are incremental.

At runtime cliamp needs an ALSA output. Linux desktops already have one (PipeWire or PulseAudio), and `vc up` uses it. On a box with no sound server and no sound card (CI, containers, VMs), `vc up` says `no sound server or card; playing into a per-run null sink` and starts one:
- It's a PulseAudio null sink inside the run's tmux server, paced in real time. A silent `pacat` stream on it keeps playback from stalling at the start. Without it, the sink works in ~2 s blocks and every new stream waits up to 2 s. PipeWire and macOS don't need this.
- The run's `$HOME/.asoundrc` routes ALSA to it, and `PULSE_SERVER` in the run's environment lets `pactl`, `cliamp --audio-device list` and `cliamp device` see it (as `Null Output`).
- Nothing machine-wide changes, and no login shell or `XDG_RUNTIME_DIR` is needed.

`--null-audio` forces this sink on a machine that does have sound.

To verify on Linux from a macOS or Windows host, use a disposable clankerbox machine. [`clankerbox.md`](clankerbox.md) covers create, ship code, drive and clean up.

Don't swap in ALSA's own `type null` PCM. It doesn't pace playback, so three 120 s tracks finish in under 5 s and every timing step turns into nonsense. Kernel dummy cards (`snd-dummy`, `snd-aloop`) are an option only on kernels with sound support and module loading. microVMs such as smolvm/libkrun boot with `nomodule` and no ALSA.

### Spotify runs

`--spotify` uses the user's real Spotify account through a **verification-only sign-in**. It is never the user's real cliamp credential. Never read, copy or touch `~/.config/cliamp/spotify_credentials.json`.

- The store is `$VC_SECRETS`, default `~/.config/cliamp-verify/` (mode 0700). It holds `spotify_credentials.json` (0600) and optionally `spotify_client_id`.
- `up` copies the stored credential into the run. `down` writes the run's copy back, because cliamp rotates the refresh token on every launch. If the store changed during the run, `down` keeps the store and discards the run's copy. If cliamp deleted the credential (`invalid_grant`), `down` removes the store too, and the next run has to sign in again.
- `spotify.lock` in the store allows one Spotify run at a time, so two runs don't race the rotating token. A lock left by a dead run is taken over.
- No stored credential: the run starts signed out. The user signs in inside the run: `$VC keys $RUN S`, then Enter on `Sign in to Spotify`, then the browser. `down` stores the result. An agent can't do this step.
- client ID: `SPOTIFY_CLIENT_ID` from the environment, else `$VC_SECRETS/spotify_client_id`, else cliamp's built-in shared ID. The built-in ID's Web API quota is shared worldwide and often exhausted (`429`, `Retry-After` up to 24 h). A refresh token belongs to the client ID that issued it, so switching client IDs needs a new sign-in.
- `down` replaces every `refresh_token` and `data` value found in the artifacts with `[REDACTED]`. Still, don't `cat` the credential file, and don't paste it anywhere.
- Consent rules: read-only by default. Start Spotify playback only when the user asks in this conversation. It streams on their account and takes over their other devices. Write to their library (likes, playlists) only with explicit OK and a planned undo.

### Media server runs

`--server NAME` starts a throwaway server in Docker for the run and points cliamp at it. It works for `navidrome`, `jellyfin`, `emby`, `plex`, `audiobookshelf` and `lyrion`. There are no real accounts: each server gets a per-run local admin, so playback and server-side writes (stars, playlists, scrobbles, progress) are fair game.

- `up` generates `/tmp/vc-RUN/library/` with `scripts/make-library`: 7 tagged 60 s tracks on 3 albums by 2 artists, cover art, a FLAC album, `Verify Playlist.m3u` (Tone 2, Chord 1), a 2-chapter audiobook and a 2-episode podcast show.
- `vc up` builds cliamp first, then starts the servers. `scripts/servers/NAME up` starts the container on `127.0.0.1:<free port>` and bootstraps it through the server's own API: admin user, library, scan finished, and a playlist where the server has them. The config block it prints goes into the run's `config.toml`. Images are pinned in each script, and the first use pulls them (100 MB to 2.5 GB).
- `$VC srv $RUN NAME status` prints the URL and test login for server-side assertions. `features/NAME.md` shows the API calls for each server.
- `down` saves `_server-NAME.log` to the artifacts and removes the container and its volumes. `docker ps -a --filter label=vc.run` lists any leftovers.
- Stream URLs carry the per-run server token or password, so it shows up in snapshots, `history.toml` and IPC artifacts. That's harmless for throwaway servers, but scrub it before sharing evidence.
- Needs a running Docker, which `up` checks before building: OrbStack or Docker Desktop on macOS, and `docker.io` (in the package list) on Linux. On clankerbox, start it with `scripts/clankerbox-docker` (see `clankerbox.md`).

## Doctor

```sh
$VC doctor $RUN     # read-only; exit 1 and "doctor: FAIL <reason>" if not worth driving
```

Checks:
- the tmux session and pane are alive (a dead pane reports cliamp's exit status)
- the socket exists at the run's config dir, and `cliamp.sock.pid` equals the pane pid (the socket is ours)
- the binary version matches the build
- no Go sources changed since the build
- with a null sink, its PulseAudio session is alive and its socket exists
- with `--spotify` and a credential, `provider.playlists` answers within 20 s; a Web API rate limit is reported as such
- with `--server`, each server answers its `status` check and cliamp's `provider.playlists` for it succeeds within 20 s
- `state.get` answers

On success it prints the state, track, total and volume.

Run it before the first drive and after any surprising result. If the process is healthy but the UI is in an unknown mode, doctor can't see that. Reset with `$VC keys $RUN Escape`, check `$VC screen $RUN`, or `down`/`up`.

## Drive

TUI keystrokes use tmux key names: `Space Enter Escape Tab BTab Up Down Left Right S-Left C-f C-k`. Printable keys are sent as-is (`+ - > < / q`).

```sh
$VC keys $RUN Space                  # one key per arg, 150 ms apart (VC_KEY_DELAY to change)
$VC type $RUN 'ton3'                 # literal text into a focused input
$VC wait-screen $RUN 'Playing' 5     # poll the pane for an ERE; prints the screen on timeout
$VC screen $RUN                      # print the pane (blank runs squeezed)
```

State and CLI:

```sh
$VC state $RUN                                   # full V2 snapshot
$VC state $RUN '.snapshot|{state,position,track:.track.title}'
$VC wait-state $RUN '.state == "playing"' 5      # jq boolean against .snapshot
$VC cli $RUN -- status --json                    # any cliamp subcommand, isolated env
$VC cli $RUN -- remote call queue.list --wait
$VC events $RUN 3 ipc/events runtime.state runtime.job &   # bounded subscription; trigger, then `wait`
$VC files $RUN                                   # files in the isolated config dir
$VC files $RUN 'playlists/Verify Mix.toml'       # print one of them
```

Stable handles to assert on:
- The header mode tag at the top right: `[Playlist]`, `[Filter]`, `[Provider]`, `[Save to Playlist]`.
- The status line: `▶ Playing`, `⏸ Paused`, `■ Stopped`.
- The time line: `00:11 / 02:00`.
- The playlist counter: `[2/3]`.
- The settings rows: `VOL … -30dB`, `SHF [On]`, `RPT [All]`, `EQ [Custom]`.
- The help bar at the bottom, and transient notices such as `Added 1 to "Verify Mix"`.

Read values from `state.get` rather than parsing the screen when both show them. The screen proves what the user sees; the snapshot proves the model.

Feature recipes live in `features/`. Start at `features/README.md`.

## Evidence

Artifacts go to `/tmp/verify-cliamp-artifacts/RUN/` (override with `VC_ARTIFACTS`). They survive `down`.

```sh
$VC screen $RUN playback/after-pause               # -> playback/after-pause.txt
$VC cli $RUN --save playback/status -- status --json  # command, stdout, stderr, exit code
$VC save $RUN 'playlists/Verify Mix.toml' save-to-playlist/file.toml
```

Proof standards:
- Drive the real user path: keystrokes for TUI features, the actual subcommand for CLI features. Don't use `remote call` as a stand-in for a keybinding, or keys as a stand-in for a subcommand.
- Capture the action and the resulting state: a screen before and after, plus the snapshot.
- Verify side effects in the isolated config dir. This includes `config.toml` keys written by toggles, `playlists/*.toml`, `history.toml`, and `resume.json` after quit.
- A transient notice alone is not proof. Read the value back through a second view (snapshot, file, or `cliamp playlist list`).
- Record the feature ID and entry point in each artifact label (`<feature-id>/<step>`).
- If a path can't be exercised, report it as unverified with the attempted command and the missing precondition. Never report it as verified through another path.

## Cleanup

```sh
$VC down $RUN     # saves _final-screen.txt, sends Ctrl+C, records _exit.txt, copies _cliamp.log,
                  # stops the null sink by pid, kills only tmux server vc-RUN,
                  # deletes /tmp/vc-RUN; prints the kept artifacts
$VC ls            # runs still on disk and whether their session is alive
```

Run `down` after every run, including failed and abandoned ones. `_exit.txt` should read `pane_dead=1 exit_status=0`; anything else is a crash worth reporting. Never `pkill cliamp`: the user may have their own instance running. `down` touches only what the run started.

## Gotchas

- A build that fails with `compile: version "goX" does not match go tool version "goY"` comes from a stale exported `GOROOT` pointing at a different Go install than the `go` on `PATH`. It breaks `make build` too. Fix the environment (or run with `env -u GOROOT`); the harness doesn't hide it.
- Isolating `HOME` also hides the user's `~/.asoundrc`. A Linux setup that relies on a per-user ALSA config needs that config reproduced for the run.
- `Esc` in the playlist opens the provider pane (`[Provider]`), where playlist keys do nothing or mean something else. Check the mode tag before sending keys, and use `Esc` again to return.
- Keys typed while a text input is focused (`[Filter]`, `New Playlist:`) go into the input: `q` doesn't quit and `n` doesn't favorite.
- Confirming a playlist filter with `Enter` plays the highlighted match immediately.
- `+`/`-` step 1 dB. `cliamp volume N` sets an absolute dB value. `cliamp seek N` is relative; `seek.absolute` is absolute.
- The daemon has no `track` in the snapshot until playback starts. The TUI shows track 1 selected while stopped.
- `cliamp theme ...` fails in daemon mode with `unknown_operation`. That is expected, not a regression.
- `status` and `remote state` print position as float seconds. The screen rounds to `mm:ss`.
