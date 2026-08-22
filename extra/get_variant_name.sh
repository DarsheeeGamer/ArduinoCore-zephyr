#!/bin/bash

# Copyright (c) Arduino s.r.l. and/or its affiliated companies
# SPDX-License-Identifier: Apache-2.0

set -e

source venv/bin/activate

# Get the variant name (NORMALIZED_BOARD_TARGET in Zephyr)
#
# BUG FIX (2026-08-21): this used to redirect cmake's stderr to /dev/null
# unconditionally. When cmake failed (e.g. find_package(Zephyr REQUIRED ...)
# not resolving), the real diagnostic was thrown away, and the caller
# (build.sh) surfaced only "Failed to get variant name from '$target'" --
# no indication of WHY. Confirmed live: two separate live CI failures
# tonight (this repo's Build UNO Q Zephyr Loader workflow) hit exactly this
# path with zero diagnostic content, forcing guesses at the root cause
# (ZEPHYR_BASE export scope was one real bug found this way, fixed
# separately -- but it did NOT resolve this failure, meaning something else
# is also wrong here and was already being hidden by this same redirect).
#
# Fix: run cmake ONCE, merging stderr into stdout (2>&1) so both streams
# are captured together -- avoids a second cmake invocation just to see
# the error, which would be wasteful and (in principle) could observe a
# different result than the first if anything about the environment
# changed between calls. Split the combined output back into the VARIANT=
# line (what callers actually want) and everything else (the diagnostic,
# only printed if the variant lookup came back empty).
#
# BUG FIX (2026-08-22): the assignment below is a command substitution
# under `set -e` (line 6) -- bash checks the exit status of a command
# substitution when it's the right-hand side of a plain assignment, and
# a non-zero exit from `cmake` (exactly what's been happening every run)
# kills THIS SCRIPT right there, before the `if [ -z "$variant" ]` check
# on the next lines ever runs. The entire point of this fix -- surfacing
# cmake's real error instead of the old silent /dev/null redirect -- was
# itself being silently skipped by set -e, for the same underlying reason
# (a failing command with nothing printed by the time the script dies).
# Confirmed directly: a minimal repro (`set -e; x=$(false_cmd 2>&1);
# echo reached`) never reaches the echo. `|| true` on the assignment lets
# execution continue past the failure while $combined still captures
# whatever cmake wrote to its now-merged stdout+stderr.
combined=$(cmake "-DBOARD=$1" -P extra/get_variant_name.cmake 2>&1) || true
variant=$(grep 'VARIANT=' <<< "$combined" | cut -d '=' -f 2)
if [ -z "$variant" ]; then
	echo "get_variant_name.sh: cmake produced no VARIANT= output; its full output was:" >&2
	echo "$combined" >&2
fi
echo $variant
