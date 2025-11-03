#!/bin/bash
echo "This is the script for Developer of application, to build it"

tz_hour="$(date -u +%z | cut -c1-3)"
start_text="$(printf '%s %s\n' "$(date +%F)${tz_hour}" "Starting test of builds")"
main_pwd="${PWD}"
log_fn="${main_pwd}/log-devbuild.txt"
echo "Logging into [$log_fn]"
echo "$start_text" > "$log_fn"
log_ok "$start_text start the multi build"

source ./lib-sh-log.sh  || { echo "Can not load lib... it is not here nor in up-dir" ; exit 1 ; }
#source ./lib-sh-log.sh || source ../lib-sh-log.sh || { echo "Can not load lib... it is not here nor in up-dir" ; exit 1 ; }


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
