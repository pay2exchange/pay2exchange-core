#!/bin/bash
echo "This is the script for Developer of application, to build it"

function log_fail() {
	if [ "$(tput colors)" -ge 256 ]; then
		BG="\e[48;5;229m"  # light yellow
	else
		BG="$(tput setab 3)"  # standard yellow
	fi
	FG="$(tput setaf 1)"      # red text
	RESET="$(tput sgr0)"

	printf -- "$*\n" | tee -a log | while read -r l; do echo -e "${BG}${FG}${l}${RESET}"; done
}

function fail() {
	log_fail "$@"
	echo "$@" "- exiting" >&2
	exit 1
}

function log_ok() {
	printf -- "$*\n" | tee -a log | while read -r l; do echo "$(tput setab 10)$(tput setaf 0)$l$(tput sgr0)"; done
}

jobs=$(./make-get-jobs 2048 110 0 256)

jobs_arg_forced=false
for arg in "$@"; do
  if [[ $arg == --jobs=* ]]; then
    jobs="${arg#--jobs=}"
    jobs_arg_forced=true
  fi
done
if $jobs_arg_forced; then
  echo "Jobs was forced via argument: $jobs"
fi

kitname=$(./kitname)
kitname="$(printf '%s' "$kitname" | sed 's/[^A-Za-z0-9._+-]/X/g')" # sanitize

function do_build() {
	build_dir="build-term-$kitname"
	banner="Build for CXX=$CXX (kitname=$kitname) jobs=$jobs"
	log_ok "$banner - starting build"
	cmake -S . -B "$build_dir" -S . -DCMAKE_BUILD_TYPE=Debug -G Ninja -DCMAKE_C_COMPILER_LAUNCHER=ccache  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DMANUAL_SUBMODULES=1  || fail "$banner - cmake failed"
	time ninja -C "$build_dir" -j ${jobs} -k0 || fail "$banner - build (generator, after cmake) failed"
	log_ok "$banner - DONE"
}

echo "======================================================================"
echo "Using $jobs job(s), using CXX=$CXX, CC=$CC."
time do_build
echo "======================================================================"
echo "Using $jobs job(s), using CXX=$CXX, CC=$CC."
echo "Finished"
