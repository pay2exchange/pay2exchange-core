#!/bin/bash
echo "This is the script for Developer of application, to build it"
jobs=$(./make-get-jobs 1024 110 0 256)
echo "using $jobs jobs"
set -x
time cmake -DCMAKE_BUILD_TYPE=Debug  -DCMAKE_C_COMPILER_LAUNCHER=ccache  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DMANUAL_SUBMODULES=1  .    && time make -j ${jobs}
