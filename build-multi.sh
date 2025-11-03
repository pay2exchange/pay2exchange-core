#!/bin/bash

tz_hour="$(date -u +%z | cut -c1-3)"
start_text="$(printf '%s %s\n' "$(date +%F)${tz_hour}" "Starting test of builds")"
main_pwd="${PWD}"
log_fn="${main_pwd}/log-multibuild.txt"
echo "Logging into [$log_fn]"
echo "$start_text" > "$log_fn"
source ./lib-sh-log.sh
log_ok "$start_text start the multi build"


jobsmax=$(./make-get-jobs-here) || { fail "Can not calculate max jobs" ; }
log_ok "Max jobs will be: $jobsmax"

function do_clean_git() {
	OLD_EXCLUDE=$(git config --get-all clean.exclude || true)

	restore_exclude() {
		git config --unset-all clean.exclude || true
		if [ -n "$OLD_EXCLUDE" ]; then
			while IFS= read -r line; do
			git config --add clean.exclude "$line" || fail "could not restore clean.exclude entry"
		done <<< "$OLD_EXCLUDE"
		fi
		log_ok "restored previous git clean.exclude"
	}

	# register trap so Ctrl-C or errors still restore
	trap restore_exclude EXIT INT TERM

	# add temporary exclusion
	git config --add clean.exclude 'log*.txt' || fail "could not add git clean temporary exclusion"
	log_ok "saved current git clean.exclude and added temporary exclusion"

	git clean -xdf && git submodule foreach --recursive 'git clean -xdf' && echo "CLEAN OK" || { fail "Can not clean git." ; }

	# --- manual restore at the end ---
	restore_exclude || fail "manual restore (of git clean excluse) failed"
	trap - EXIT INT TERM # now unregister the trap so it won't run again

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
		log_ok "Build with jobs: $var_jobs"
		bash dev.sh --jobs=$var_jobs && log_ok "Worked ok for jobs=$var_jobs with CC=$CC CXX=$CXX" || fail "Failed build wih jobs=$var_jobs"
	done
}

function build_by_kit() {
	log_ok "Kit $1 - start"
	source "$1" || fail "Can not load kit [$1]"
	build_by_j 1 "$jobsmax" || fail "Failed build j"
	log_ok "Kit $1 - DONE"
}

log_ok "Will stat bulding all the kits now..."
build_by_kit ~/use-clang-18
build_by_kit ~/use-clang-20
build_by_kit ~/use-gcc
log_ok "This is all, bye."

