#!/bin/bash
echo "This is the script for Developer of application, to build it"
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

echo "======================================================================"
echo "Using $jobs job(s), using CXX=$CXX, CC=$CC."
set -x
time cmake -DCMAKE_BUILD_TYPE=Debug -G Ninja -DCMAKE_C_COMPILER_LAUNCHER=ccache  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DMANUAL_SUBMODULES=1  .    && printf "\n\n\nmake with $jobs jobs.\n\n" && time ninja -j ${jobs}
echo "======================================================================"
echo "Using $jobs job(s), using CXX=$CXX, CC=$CC."
echo "Finished"
