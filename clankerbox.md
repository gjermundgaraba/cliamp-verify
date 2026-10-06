# Verify cliamp on Linux with clankerbox

Use a clankerbox machine when you need to prove behavior on Linux from a non-Linux host. Use the `cliamp-dev` profile. The machine is a disposable Ubuntu microVM (smolvm, x86_64, 2 CPU, 1 GiB) with the packages from SKILL.md, Launch. It has no sound card and no systemd, so `vc up` plays into its per-run null sink, at real-time speed.

Everything below runs on your host, from the root of the cliamp checkout you're verifying, with clankerbox 0.12 or later. `SKILL` is this skill's directory, and `M` is the machine's ID.

Once, put your SSH public key where the recipe reads it. It stays out of git:

```sh
cp ~/.ssh/id_ed25519.pub "$SKILL/clankerbox-profile/files/authorized_keys"
```

## 1. Create

```sh
clankerbox machines                          # pick a name nobody else uses
M=$(clankerbox create --profile "$SKILL/cliamp-dev.json" verify-cliamp)
vm() { clankerbox ssh "$M" -- -l root "$@"; }
vm 'test ! -e /usr/sbin/init && echo ready'  # ready
```

`create` returns once setup has run, with the machine running, and prints its ID (`hetzner-linux_verify-cliamp`). `vm` runs one command as root over ssh; quote it as one string, since the machine's shell reads it. Leave every machine you did not create alone.

The `cliamp-dev` profile is [`cliamp-dev.json`](cliamp-dev.json), with its recipe in [`clankerbox-profile/`](clankerbox-profile/). Its `setup.sh`, which runs once at create:
- installs `files/debian-packages`, the skill's one package list, and sshd, without recommends, and lets root in with `files/authorized_keys`
- writes `/etc/clankerbox/start`, which starts sshd on every boot, since the machine has no init system
- diverts systemd's `/usr/sbin/init` and fails if one appears anyway or `/etc/resolv.conf` isn't a regular file (see Gotchas)
- configures apt to retry and to fail a partial update, and ships no apt index

Go isn't baked in. The first `vc up` on a new machine downloads the toolchain and modules and builds cold, about 1.5 minutes. The profile is placed on the first host that offers the `ubuntu` base; add `"host"` to it to pick one. A recipe change applies to machines created after it, so prove it with a fresh `create` and then a `stop`/`start` cycle. A failing setup fails the create with its last 20 lines of output; delete that machine before you try again.

## 2. Ship the code

The worktree is not on the machine. Send the commit as a git bundle that includes the nearest tag, so `git describe` (and the doctor's version check) matches the host. The skill goes to its own directory, `/root/verify-cliamp`.

```sh
TAG=$(git describe --tags --abbrev=0)
git bundle create /tmp/cliamp-e2e.bundle HEAD "$TAG"
vm 'cat > /root/cliamp.bundle' < /tmp/cliamp-e2e.bundle && rm /tmp/cliamp-e2e.bundle
COPYFILE_DISABLE=1 tar --no-xattrs -C "$SKILL" -cf - . | vm 'rm -rf /root/verify-cliamp && mkdir /root/verify-cliamp && tar -xf - -C /root/verify-cliamp'
vm 'rm -rf /root/cliamp && cd /root && git -c advice.detachedHead=false clone -q cliamp.bundle cliamp && cd cliamp \
  && git -c advice.detachedHead=false checkout -q --detach '"$(git rev-parse HEAD)"' && git describe --tags --always --dirty'
```

The last command prints the same version as `git describe --tags --always --dirty` on the host. That only holds when the host tree is clean. Uncommitted Go changes don't travel in a bundle, so commit them (a WIP commit is fine) before shipping.

To re-ship after a change, run the whole block again. Both directories are replaced.

## 3. Drive

Use the normal `vc` workflow from SKILL.md, on the machine.

One command at a time:

```sh
vm 'cd /root/cliamp && RUN=$(/root/verify-cliamp/scripts/vc up) && echo $RUN > /tmp/run-id'
vm '/root/verify-cliamp/scripts/vc keys $(cat /tmp/run-id) Space'
vm '/root/verify-cliamp/scripts/vc state $(cat /tmp/run-id)'
```

Every `vm` call is a new ssh session, so shell variables don't survive between calls. Keep the run ID in a file on the machine, as above.

For a whole feature file, write the recipe as a local script and pipe it in:

```sh
vm 'bash -s' < /tmp/recipe.sh
```

The script runs top to bottom in one session, so `RUN` survives. Start it with `cd /root/cliamp; VC=/root/verify-cliamp/scripts/vc`, and end it with `$VC down $RUN`.

Artifacts land on the machine under `/tmp/verify-cliamp-artifacts/RUN/`. Pull the ones you need back to the host:

```sh
mkdir -p /tmp/verify-cliamp-artifacts
vm 'tar -C /tmp/verify-cliamp-artifacts -cf - .' | tar -C /tmp/verify-cliamp-artifacts -xf -
```

### Media servers (`vc up --server NAME`)

The profile installs Docker, but nothing starts it (no systemd). Start it once per machine, and again after a `stop`/`start`:

```sh
vm 'sh /root/verify-cliamp/scripts/clankerbox-docker'   # expect: clankerbox-docker: ready
```

It takes a few seconds. The script puts Docker's storage on a 6 GB loop-mounted ext4 image, because overlay on the machine's overlay root fails with `invalid argument`, and makes the loop device nodes the machine's `/dev` lacks. It also starts the daemons with `umask 022`, so non-root processes in a container can read their image layers.

Then use `vc up --server NAME` as on the host. Budget for the 1 GiB machine:
- Run one server at a time. Jellyfin and Plex use about 300 MiB each, and cliamp plus a server fits.
- Images take 0.3 to 2.5 GB of the 6 GB store. Between servers, clear them with `docker rmi -f $(docker images -q)`.
- A machine `stop` doesn't flush the loop image. A container removed just before it can come back after `start` as a ghost that `docker ps` lists but `docker rm` can't delete. No run survives a stop, so `clankerbox-docker` deletes leftover vc containers from disk before it starts Docker, then prunes unused volumes.

## 4. Fork (optional, currently broken after a build)

A machine with the code shipped would be a good base for parallel or throwaway runs:

```sh
F=$(clankerbox fork "$M" verify-cliamp-2)
```

The child continues the machine's memory and keeps the shipped code in `/root/cliamp`. **On clankerbox 0.12.1 a fork of a machine that has built cliamp fails** (`preparation exited 1 … connection closed`), or its child stops on its own seconds later. Forking before the first `vc up` works, but then each child builds cold. Delete a failed child (`clankerbox delete`) and create a fresh machine instead.

## 5. Clean up

`vc down` every run first (step 3), and pull the artifacts you need. Then remove the machines you created:

```sh
clankerbox delete "$M"
clankerbox machines                          # yours are gone; others are untouched
```

`delete` stops a running machine itself. Artifacts on the machine go with it.

## Gotchas

- **No apt index.** `cliamp-dev` ships without one, so run `apt-get update` before installing anything by hand.
- **Flaky DNS.** Name resolution in the VM can fail intermittently (`Temporary failure resolving`). `cliamp-dev` configures apt to retry with backoff (`/etc/apt/apt.conf.d/80-clankerbox`). Other tools may fail once and then succeed.
- **Small `/tmp`.** `/tmp` is a RAM tmpfs of half the machine's RAM, about 500 MiB, which a cold build of cliamp overflows at the link (`No space left on device`). `cliamp-dev` sets `TMPDIR=/var/tmp` in `/etc/environment`, which every ssh session gets. A shell that doesn't come from ssh doesn't have it.
- **No kernel audio.** The kernel has no ALSA, so `snd-dummy`/`snd-aloop` can't work, and a recipe can't change the kernel. Userspace audio (`vc`'s per-run null sink) is the only option.
- **macOS tar metadata.** Without `COPYFILE_DISABLE=1 tar --no-xattrs`, extraction on the machine warns about `LIBARCHIVE.xattr.com.apple.provenance`. The warnings are harmless but noisy.
- **Locale warnings.** ssh passes your `LANG` along, and the machine has no locales, so perl and apt warn `Setting locale failed`. Harmless.
- **stdin is the script.** With `bash -s`, anything in the recipe that reads stdin eats the rest of the script, and later lines silently never run. `vc` keeps ffmpeg off stdin. Add `</dev/null` to other stdin readers you put in a recipe.
- **A failed action** shows in `clankerbox machines` (`ACTION` reads, for example, `fork failed: Precondition`), and `--json` on the command gives its message. `delete` works on a machine in any state, so delete what failed rather than retrying on it.
- **systemd must not take over.** PulseAudio (like PipeWire) hard-depends on `systemd-sysv` here, even without recommends, and `systemd-sysv` installs `/usr/sbin/init`. The stock image has none: smolvm's agent boots the machine, and systemd must not.

  The recipe diverts systemd's init to `/usr/sbin/init.systemd-sysv`. It also skips recommended packages, because `systemd-resolved` turns `/etc/resolv.conf` into a link that dangles without systemd: DNS works until the next boot, then dies with `lookup … on [::1]:53: connection refused`.

  Setup fails if either goes wrong. On a machine, check with `ls /usr/sbin/init` (expect no such file) and `ls -l /etc/resolv.conf` (expect a regular file). Don't install such packages by hand on a machine from another profile without the divert.
