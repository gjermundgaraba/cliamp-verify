# shellcheck shell=bash
# Shared code for scripts/servers/<name>. Sourced, not executed. A server script sets IMAGE,
# defines srv_up and srv_status (and srv_logs if `docker logs` isn't enough), then calls srv_main "$@".
#
# Contract (RUNDIR is /tmp/vc-RUN; the script's name is cliamp's provider key):
#   <name> up RUNDIR       start the server, bootstrap it headlessly (admin user, library, scan
#                          finished, server-side playlist where supported), then print the cliamp
#                          TOML config block on stdout. Progress goes to stderr. Exit 1 on failure.
#   <name> status RUNDIR   exit 0 if the server answers; print one line (url, and the test login)
#   <name> logs RUNDIR     print the server's log (vc down saves it to artifacts)
#   <name> down RUNDIR     remove the container and its anonymous volumes; idempotent
# Inputs: RUNDIR/library (scripts/make-library). State: RUNDIR/srv-<name>/ (port, credentials).
# Containers are named vc-<ID>-<name>, labelled vc.run=<ID>, and publish one port on 127.0.0.1 only.
# Credentials are local, disposable, per run.

# shellcheck disable=SC2034 # variables here are used by the scripts that source this file.
set -eo pipefail

SRV_NAME=$(basename "$0")
PLAYLIST="Verify Playlist"

log() { echo "$SRV_NAME: $*" >&2; }
fail() { echo "$SRV_NAME: $*" >&2; exit 1; }

# srv_main up|status|logs|down RUNDIR: set RUNDIR, ID, LIB, STATE, CTR, PORT and URL, then run the
# subcommand. `up` picks the port; the others read it back.
srv_main() {
	case ${1:-}:${2:-} in up:?* | status:?* | logs:?* | down:?*) ;; *) fail "usage: $SRV_NAME up|status|logs|down RUNDIR" ;; esac
	RUNDIR=$2
	[ -d "$RUNDIR" ] || fail "no run dir $RUNDIR"
	ID=${RUNDIR##*/vc-}
	LIB=$RUNDIR/library
	STATE=$RUNDIR/srv-$SRV_NAME
	CTR=vc-$ID-$SRV_NAME
	mkdir -p "$STATE"
	if [ "$1" = up ] && [ ! -s "$STATE/port" ]; then free_port >"$STATE/port"; fi
	PORT=$(load port)
	URL=http://127.0.0.1:$PORT
	case $1 in
	up) [ -d "$LIB" ] || fail "no fixture library at $LIB (scripts/make-library)"; srv_up ;;
	status) [ -n "$PORT" ] || fail "not started"; srv_status ;;
	logs) if declare -F srv_logs >/dev/null; then srv_logs; else ctr_logs; fi ;;
	down) ctr_down ;;
	esac
}

# free_port: an unused TCP port on 127.0.0.1.
free_port() { perl -MIO::Socket::INET -e 'print IO::Socket::INET->new(Listen=>1,LocalAddr=>"127.0.0.1",LocalPort=>0)->sockport'; }

# ctr_run CONTAINER_PORT [docker run args...]: start IMAGE as the run's container, detached, with
# CONTAINER_PORT published on 127.0.0.1:$PORT.
ctr_run() {
	local cport=$1; shift
	log "starting $IMAGE on $URL"
	docker run -d --name "$CTR" --label "vc.run=$ID" -p "127.0.0.1:$PORT:$cport" "$@" "$IMAGE" >/dev/null ||
		fail "docker run $IMAGE failed"
}
ctr_logs() { docker logs "$CTR" 2>&1 || true; }
ctr_down() { docker rm -f -v "$CTR" >/dev/null 2>&1 || true; }

# wait_for SECS CMD...: poll CMD (twice a second) until it succeeds.
wait_for() {
	local secs=$1 _; shift
	for _ in $(seq 1 $((secs * 2))); do
		"$@" >/dev/null 2>&1 && return 0
		sleep 0.5
	done
	return 1
}
# wait_http URL SECS: poll until URL answers 2xx/3xx.
wait_http() { wait_for "$2" curl -fs --max-time 3 "$1"; }

# save KEY VALUE / load KEY: tiny per-run key-value store in STATE.
save() { printf '%s' "$2" >"$STATE/$1"; }
load() { cat "$STATE/$1" 2>/dev/null || true; }

# Fixture facts, read from the library so that make-library stays their only source.
lib_tracks() { find "$LIB/music" -type f \( -name '*.mp3' -o -name '*.flac' \) | wc -l | tr -d ' '; }
lib_albums() { find "$LIB/music" -mindepth 2 -maxdepth 2 -type d | wc -l | tr -d ' '; }
# lib_playlist: the title tags of the playlist's .m3u entries, in order, as a JSON array.
lib_playlist() {
	local f
	grep -v '^#' "$LIB/music/$PLAYLIST.m3u" | while IFS= read -r f; do
		ffprobe -v error -show_entries format_tags=title -of default=nw=1:nk=1 "$LIB/music/$f" </dev/null
	done | jq -Rn '[inputs]'
}
