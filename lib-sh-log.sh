#!/bin/bash
function log_fail() {
	if [ "$(tput colors)" -ge 256 ]; then
		BG="\e[48;5;229m"  # light yellow
	else
		BG="$(tput setab 3)"  # standard yellow
	fi
	FG="$(tput setaf 1)"      # red text
	RESET="$(tput sgr0)"

	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	shortbanner="$0: $timestamp: "
	echo "(log goes to: $log_fn)"
	printf -- "$shortbanner $*\n" | tee -a "$log_fn" | while read -r l; do echo -e "${BG}${FG}${l}${RESET}"; done
}

function log_ok() {
	timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	shortbanner="$0: $timestamp: "
	printf -- "($shortbanner log goes to $log_fn) - $*\n" | tee -a "$log_fn" | while read -r l; do echo "$(tput setab 10)$(tput setaf 0)$l$(tput sgr0)"; done
}

function fail() {
	log_fail "$@"
	echo "$@" "- exiting" >&2
	exit 1
}

