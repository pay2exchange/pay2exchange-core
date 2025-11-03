#!/bin/bash


tz_hour="$(date +%z | cut -c1-3)"
start_text="$(printf '%s %s\n' "$(date +%F)${tz_hour}" "Starting test of builds")"
log_fn="${PWD}/log.txt"

echo "$start_text" > "$log_fn"
log_ok "$start_text"

function log_fail() {
	if [ "$(tput colors)" -ge 256 ]; then
		BG="\e[48;5;229m"  # light yellow
	else
		BG="$(tput setab 3)"  # standard yellow
	fi
	FG="$(tput setaf 1)"      # red text
	RESET="$(tput sgr0)"

	printf -- "$*\n" | tee -a "$log_fn" | while read -r l; do echo -e "${BG}${FG}${l}${RESET}"; done
}

function fail() {
	log_fail "$@"
	echo "$@" "- exiting" >&2
	exit 1
}

function log_ok() {
	printf -- "$*\n" | tee -a "$log_fn" | while read -r l; do echo "$(tput setab 10)$(tput setaf 0)$l$(tput sgr0)"; done
}



jobsmax=$(./make-get-jobs-here) || { fail "Can not calculate max jobs" ; }
log_ok "Max jobs will be: $jobsmax"

function do_clean_git() {
	git clean -xdf && git submodule foreach --recursive 'git clean -xdf' && echo "CLEAN OK" || { fail "Can not clean git." ; }
	log_ok "Clean done"
}


generate_seq() {
  local A=$1
  local N=$2
  #echo "A=$A N=$N"
  local -a out
  declare -A seen=()

  append_if_new() {
    local v=$1
    if (( v >= A && v <= N )) && [[ -z "${seen[$v]}" ]]; then
      out+=("$v")
      seen[$v]=1
    fi
  }

  append_if_new "$N"

  if (( N % 2 == 0 )); then
    append_if_new $(( N / 2 ))
  fi

  append_if_new 2
  append_if_new 1

   if (( N < A )); then
    return 0
  fi

  diff=$(( N - A ))
  # integer rounding: (diff + 2) / 5 gives nearest integer
  step=$(( (diff + 2) / 5 ))
  if (( step < 1 )); then step=1; fi

  for (( i = N; i >= A; i-= step )); do
    append_if_new "$i"
  done

  # print as space-separated list (one line)
  printf '%s\n' "${out[*]}"
}


function build_by_j() {
	read -r -a seq <<< "$(generate_seq "$1" "$2")"
	echo "${seq[*]}"
	log_ok "Will build with jobs number: ${seq[@]}"
	for var_jobs in "${seq[@]}"
	do
		do_clean_git || fail "Can not clean"
		echo "Build with jobs: $var_jobs"
		bash dev.sh --jobs=$var_jobs && log_ok "Worked ok for jobs=$var_jobs with CC=$CC CXX=$CXX" || fail "Failed build wih jobs=$var_jobs"
	done
}

function build_by_kit() {
	log_ok "Kit $1 - start"
	source "$1" || fail "Can not load kit [$1]"
	build_by_j 1 "$jobsmax" || fail "Failed build j"
	log_ok "Kit $1 - DONE"
}

build_by_kit ~/use-clang-18
build_by_kit ~/use-clang-20
build_by_kit ~/use-gcc

