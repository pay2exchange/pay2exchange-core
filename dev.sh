#!/bin/bash
echo "This is the script for Developer of application, to build it"
set -x
time cmake -DCMAKE_BUILD_TYPE=Debug  -DCMAKE_C_COMPILER_LAUNCHER=ccache  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DMANUAL_SUBMODULES=1  .    && time make -j 10 "$@"
