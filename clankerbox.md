# Verify cliamp on Linux with clankerbox

Use a clankerbox machine when you need to prove behavior on Linux from a non-Linux host. Use the `cliamp-dev` profile. The machine is a disposable Ubuntu microVM (smolvm, x86_64, 2 CPU, 1 GiB) with the packages from SKILL.md, Launch. It has no sound card and no systemd, so `vc up` plays into its per-run null sink, at real-time speed.

Everything below runs on your host, from the root of the cliamp checkout you're verifying. `M` is the machine name, and `SKILL` is this skill's directory.

```sh
M=verify-cliamp
```

## 1. Create

```sh
clankerbox profiles                          # expect cliamp-dev
clankerbox machines                          # pick a name nobody else uses
clankerbox create --profile cliamp-dev $M
clankerbox shell -T $M -- readlink /usr/sbin/init   # ../local/bin/smolvm-agent
```

Ready means `State: running` and that line. Leave every machine you did not create alone.

The `cliamp-dev` recipe is [`clankerbox-profile/`](clankerbox-profile/). Its `setup.sh`:
- installs `files/debian-packages`, the skill's one package list, without recommends
- diverts systemd's `/usr/sbin/init` and refuses to publish if the agent's init or a regular `/etc/resolv.conf` is gone (see Gotchas)
- configures apt to retry and to fail a partial update, and ships no apt index

Go isn't baked in. The first `vc up` on a new machine downloads the toolchain and modules and builds cold, about 1.5 minutes (9 s toolchain, 17 s modules, 70 s compile). `profile.json` names the host (`host_id`), so adjust it for another host. After changing the package list or the recipe, republish:

```sh
clankerbox profile publish "$SKILL/clankerbox-profile" --wait   # expect: Build …: succeeded (done)
```

Publishing replaces the shared profile on the host. Agree on it with the host's owner. `Build log unavailable: deadline_exceeded` lines during publish only mean the log stream timed out. The final `succeeded` or `failed` line is the result, and `clankerbox profile logs BUILD_ID` has the setup output. Prove a recipe change with a `stop`/`start` cycle, not only a fresh `create`.

## 2. Ship the code

The worktree is not on the machine. Send the commit as a git bundle that includes the nearest tag, so `git describe` (and the doctor's version check) matches the host. The skill goes to its own directory, `/root/verify-cliamp`.

```sh
TAG=$(git describe --tags --abbrev=0)
git bundle create /tmp/cliamp-e2e.bundle HEAD "$TAG"
clankerbox shell -T $M -- bash -c 'cat > /root/cliamp.bundle' < /tmp/cliamp-e2e.bundle && rm /tmp/cliamp-e2e.bundle
COPYFILE_DISABLE=1 tar --no-xattrs -C "$SKILL" -cf - . | clankerbox shell -T $M -- bash -c 'rm -rf /root/verify-cliamp && mkdir /root/verify-cliamp && tar -xf - -C /root/verify-cliamp'
clankerbox shell -T $M -- bash -c 'rm -rf /root/cliamp && cd /root && git -c advice.detachedHead=false clone -q cliamp.bundle cliamp && cd cliamp \
  && git -c advice.detachedHead=false checkout -q --detach '"$(git rev-parse HEAD)"' && git describe --tags --always --dirty'
```

The last command prints the same version as `git describe --tags --always --dirty` on the host. That only holds when the host tree is clean. Uncommitted Go changes don't travel in a bundle, so commit them (a WIP commit is fine) before shipping.

To re-ship after a change, run the whole block again. Both directories are replaced.

## 3. Drive

Use the normal `vc` workflow from SKILL.md, on the machine. Any shell works.

One command at a time:

```sh
clankerbox shell -T $M -- bash -c 'cd /root/cliamp && RUN=$(/root/verify-cliamp/scripts/vc up) && echo $RUN > /tmp/run-id'
clankerbox shell -T $M -- bash -c '/root/verify-cliamp/scripts/vc keys $(cat /tmp/run-id) Space'
clankerbox shell -T $M -- bash -c '/root/verify-cliamp/scripts/vc state $(cat /tmp/run-id)'
```

Every `clankerbox shell` is a new session, so shell variables don't survive between calls. Keep the run ID in a file on the machine, as above.

For a whole feature file, write the recipe as a local script and pipe it in:

```sh
clankerbox shell -T $M -- bash -c 'bash -s' < /tmp/recipe.sh
```

The script runs top to bottom in one session, so `RUN` survives. Start it with `cd /root/cliamp; VC=/root/verify-cliamp/scripts/vc`, and end it with `$VC down $RUN`.

Artifacts land on the machine under `/tmp/verify-cliamp-artifacts/RUN/`. Pull the ones you need back to the host:

```sh
mkdir -p /tmp/verify-cliamp-artifacts
clankerbox shell -T $M -- bash -c 'tar -C /tmp/verify-cliamp-artifacts -cf - .' | tar -C /tmp/verify-cliamp-artifacts -xf -
```

### Media servers (`vc up --server NAME`)

The profile installs Docker, but nothing starts it (no systemd). Start it once per machine, and again after a `stop`/`start`:

```sh
clankerbox shell -T $M -- bash -lc 'sh /root/verify-cliamp/scripts/clankerbox-docker'   # expect: clankerbox-docker: ready
```

It takes a few seconds. The script puts Docker's storage on a 6 GB loop-mounted ext4 image, because overlay on the box's overlay root fails with `invalid argument`. It also starts the daemons with `umask 022`. With the box's default umask of 0077, every non-root process in a container gets `Permission denied`.

Then use `vc up --server NAME` as on the host. Budget for the 1 GiB machine:
- Run one server at a time. Jellyfin and Plex use about 300 MiB each, and cliamp plus a server fits.
- Images take 0.3 to 2.5 GB of the 6 GB store. Between servers, clear them with `docker rmi -f $(docker images -q)`.
- A machine `stop` doesn't flush the loop image. A container removed just before it can come back after `start` as a ghost that `docker ps` lists but `docker rm` can't delete. No run survives a stop, so `clankerbox-docker` deletes leftover vc containers from disk before it starts Docker, then prunes unused volumes.

## 4. Fork (optional)

A machine with the code shipped is a good base for parallel or throwaway runs:

```sh
clankerbox fork $M $M-fork
```

The child keeps the shipped code in `/root/cliamp`. Run `vc up` there as usual.

## 5. Clean up

`vc down` every run first (step 3). Then remove the machines you created:

```sh
clankerbox stop $M && clankerbox delete $M
clankerbox machines                          # yours are gone; others are untouched
```

`delete` refuses a running machine (`action requires a stopped machine`), so stop it first. Artifacts on the machine go with it, so pull them first.

## Gotchas

- **Stale apt index in the base image.** The image can ship apt lists whose mtimes are newer than their content. apt then sends `If-Modified-Since`, gets a 304, keeps the stale index, and fails with `404 Not Found` on superseded packages. `cliamp-dev` ships without an apt index, so run `apt-get update` before installing anything by hand.
- **Flaky DNS.** Name resolution in the VM fails intermittently (`Temporary failure resolving`). `cliamp-dev` configures apt to retry with backoff (`/etc/apt/apt.conf.d/80-clankerbox`). Other tools may fail once and then succeed.
- **No kernel audio.** The kernel boots with `nomodule` and has no ALSA, so `snd-dummy`/`snd-aloop` can't work, and a profile recipe can't change the kernel. Userspace audio (`vc`'s per-run null sink) is the only option.
- **macOS tar metadata.** Without `COPYFILE_DISABLE=1 tar --no-xattrs`, extraction on the machine warns about `LIBARCHIVE.xattr.com.apple.provenance`. The warnings are harmless but noisy.
- **Ownership isn't preserved.** Profile capture drops file ownership, so `/root` and `/etc/resolv.conf` belong to an unknown UID. Daemons that check their home, such as a system-style `pulseaudio`, refuse to start with `Home directory not accessible`. Give them their own `HOME`. `vc`'s sink already runs with the run's home.
- **Clock skew.** The VM clock can run minutes behind the host, and tar warns that timestamps are "in the future". That's harmless. Don't compare host and machine timestamps in proofs.
- **stdin is the script.** With `bash -s`, anything in the recipe that reads stdin eats the rest of the script, and later lines silently never run. `vc` keeps ffmpeg off stdin. Add `</dev/null` to other stdin readers you put in a recipe.
- **Stuck operations.** If a lifecycle operation fails on the host (for example a fork whose child service won't start), `clankerbox operation ID` can show `unresolved` indefinitely. That reserves the machines involved: sessions and `delete` return `resource is reserved by a pending or unresolved operation`. The CLI can't cancel it. Stop and report the operation ID to whoever runs the clankerbox host instead of retrying. One likely cause is a child that can't boot because systemd replaced its init (next item).
- **systemd must not take over.** PulseAudio (like PipeWire) hard-depends on `systemd-sysv` here, even without recommends. `systemd-sysv` replaces `/usr/sbin/init` (normally a link to `smolvm-agent`), and a machine booted with systemd instead of the agent never comes up. Publish validation fails with `Job for clankerbox-….service failed`, and a cold-booting fork or `start` hangs.

  The recipe diverts systemd's init to `/usr/sbin/init.systemd-sysv`. It also skips recommended packages, because `systemd-resolved` turns `/etc/resolv.conf` into a link that dangles without systemd: DNS works until the next boot, then dies with `lookup … on [::1]:53: connection refused`.

  The recipe checks both before publishing. On a machine, check with `readlink /usr/sbin/init` (expect `../local/bin/smolvm-agent`) and `ls -l /etc/resolv.conf` (expect a regular file). Installing such packages by hand on a plain `linux-dev` machine without the divert breaks its next boot.
- **Backslashes in paths (clankerbox before 0.10.1).** Older hosts reject any captured path containing `\`, and a build then fails with `unsafe rootfs archive path`. systemd ships escaped unit names such as `system-systemd\x2dmute\x2dconsole.slice`. From 0.10.1 on, capture accepts them and the `cliamp-dev` recipe needs no workaround. On an older host, delete those unused slices at the end of `setup.sh` (`find /usr/lib/systemd /etc/systemd -name '*\\*' -delete`).
