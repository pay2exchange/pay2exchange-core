#!/usr/bin/env bash
#
# link_time.sh: wrap the real linker, measure elapsed time in ms, and forward output.
#

# Grab high-precision start time (ms since epoch)

echo "Timer - link wrapper" >&2
start_ms=$(date +%s%3N)

# Invoke the real linker (first arg is the actual linker path)
# $0 is this script; $1 is the real linker; $@ are all args
real_linker="$1"
shift
"$real_linker" "$@"
exit_code=$?

# Compute elapsed time
end_ms=$(date +%s%3N)
elapsed=$((end_ms - start_ms))

# Print timing info to stderr so it shows in your build logs
echo "LINKED [$real_linker] in ${elapsed} ms. " >&2

exit $exit_code
