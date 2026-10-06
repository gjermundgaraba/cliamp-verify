#!/bin/sh
set -eu

# Runs once as root at create, from this recipe directory, on stock Ubuntu 26.04
# (base `ubuntu`, smolvm). Builds a box that can build cliamp and run its
# verify-cliamp skill; vc starts a per-run PulseAudio null sink itself.
# files/debian-packages is the skill's one package list (SKILL.md, Launch).
# Timeout 600 s: create took 59 s on hetzner-linux (2026-10-06), with room for
# apt's retries on flaky DNS.
export DEBIAN_FRONTEND=noninteractive

test -s files/authorized_keys || { echo "setup: put your SSH public key in clankerbox-profile/files/authorized_keys" >&2; exit 1; }

# Name resolution in the VM fails intermittently: retry fetches with backoff, and
# fail a partial `apt-get update` instead of installing from whatever index is left.
cat >/etc/apt/apt.conf.d/80-clankerbox <<'CONF'
Acquire::Retries "5";
APT::Update::Error-Mode "any";
CONF

# pulseaudio hard-depends on systemd-sysv. The stock image has no /usr/sbin/init
# (smolvm's agent boots the guest); divert systemd's so none appears.
dpkg-divert --local --no-rename --divert /usr/sbin/init.systemd-sysv --add /usr/sbin/init

apt-get update
# No recommends: systemd-resolved would turn /etc/resolv.conf into a link that
# dangles without systemd. The distro Go fetches the version go.mod asks for.
# shellcheck disable=SC2046 # one package per line, split on purpose
apt-get install -y --no-install-recommends openssh-server $(cat files/debian-packages)
apt-get clean
rm -rf /var/lib/apt/lists/*

# Root logs in with the operator's key: `clankerbox ssh ID -- -l root`. The key is the
# operator's own and stays out of git (clankerbox.md, Create); setup checks it first.
install -d -m 700 /root/.ssh
install -m 600 files/authorized_keys /root/.ssh/authorized_keys

# /tmp is a RAM tmpfs of half the machine's RAM, too small for a cold Go build's work
# directory and link; pam_env gives every ssh session this TMPDIR on disk.
echo TMPDIR=/var/tmp >>/etc/environment

# Runs after every create, start, fork and restore, under exec. The guest has no
# init system, so it launches sshd itself, unless the one in /run/sshd.pid lives.
install -d /etc/clankerbox
cat >/etc/clankerbox/start <<'START'
#!/bin/sh
set -eu
mkdir -p /run/sshd
pid=$(cat /run/sshd.pid 2>/dev/null || true)
if [ -z "$pid" ] || [ "$(cat "/proc/$pid/comm" 2>/dev/null || true)" != sshd ]; then
  /usr/sbin/sshd
fi
START
chmod 755 /etc/clankerbox/start

# Refuse a box that can't boot or resolve names.
[ ! -e /usr/sbin/init ] || { echo "setup: something installed /usr/sbin/init" >&2; exit 1; }
[ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ] || { echo "setup: /etc/resolv.conf is not a regular file" >&2; exit 1; }
