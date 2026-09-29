#!/bin/sh
set -eu

# Runs as root from this recipe directory. Builds a box that can build cliamp and
# run its verify-cliamp skill; vc starts a per-run PulseAudio null sink itself.
# files/debian-packages is the skill's one package list (SKILL.md, Launch).
export DEBIAN_FRONTEND=noninteractive

# Name resolution in the VM fails intermittently: retry fetches with backoff, and
# fail a partial `apt-get update` instead of installing from whatever index is left.
cat >/etc/apt/apt.conf.d/80-clankerbox <<'CONF'
Acquire::Retries "5";
APT::Update::Error-Mode "any";
CONF

# pulseaudio hard-depends on systemd-sysv, whose /usr/sbin/init would replace the
# smolvm agent and the machine would never boot. Divert systemd's copy aside.
dpkg-divert --local --no-rename --divert /usr/sbin/init.systemd-sysv --add /usr/sbin/init

# The base ships apt lists with build-time mtimes: apt gets 304s, keeps the stale
# index and 404s on superseded packages. Start clean, and ship no index either.
rm -rf /var/lib/apt/lists/*
apt-get update
# No recommends: systemd-resolved would turn /etc/resolv.conf into a link that
# dangles without systemd. The distro Go fetches the version go.mod asks for.
# shellcheck disable=SC2046 # one package per line, split on purpose
apt-get install -y --no-install-recommends $(cat files/debian-packages)
apt-get clean
rm -rf /var/lib/apt/lists/*

# Refuse to publish a box that can't boot or resolve names.
[ "$(readlink /usr/sbin/init)" = ../local/bin/smolvm-agent ] || { echo "setup: /usr/sbin/init was replaced" >&2; exit 1; }
[ -f /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ] || { echo "setup: /etc/resolv.conf is not a regular file" >&2; exit 1; }
