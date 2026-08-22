# Copyright (c) Arduino s.r.l. and/or its affiliated companies
# SPDX-License-Identifier: Apache-2.0

#
# Generate NORMALIZED_BOARD_TARGET from BOARD via the Zephyr build system
#

cmake_minimum_required(VERSION 3.20.0)

# BUG FIX (2026-08-21): 'python' was missing from COMPONENTS. Traced through
# Zephyr's own package machinery (share/zephyr-package/cmake/ZephyrConfig.cmake's
# include_boilerplate macro, upstream zephyrproject-rtos/zephyr): when
# find_package(Zephyr) is called with an EXPLICIT COMPONENTS list (as here),
# it does NOT fall back to cmake/modules/zephyr_default.cmake (the file that
# unconditionally appends 'python' to the module list before 'boards', for
# exactly this reason) -- it does a bare `include(${component})` for each
# name literally given and nothing else. cmake/modules/boards.cmake calls
# `execute_process(COMMAND ${PYTHON_EXECUTABLE} ${ZEPHYR_BASE}/scripts/
# list_boards.py ...)` to actually resolve the board, but with only
# `COMPONENTS yaml boards` requested, PYTHON_EXECUTABLE was never set by
# anything -- cmake/modules/python.cmake (the module that sets it) was never
# loaded, since it wasn't named and 'boards' does not declare it as a
# dependency at the find_package layer (only zephyr_default.cmake's own
# hardcoded ordering provides that ordinarily).
#
# Confirmed via live CI: multiple consecutive failures at exactly this
# find_package call, surfacing only as "Failed to get variant name from
# '$target'" further up the call chain (extra/get_variant_name.sh's own
# error-swallowing, fixed separately) -- with zero indication of WHY until
# tracing this file's actual component list against Zephyr's own component-
# loading logic directly, since PYTHON_EXECUTABLE being unset produces a
# cmake execute_process() error, not a Python traceback, and that error was
# being discarded before this session's own get_variant_name.sh fix
# surfaced it.
#
# Fix: add 'python' to COMPONENTS, ordered first -- matching the order
# zephyr_default.cmake itself uses (python is appended before boards there
# too), since 'boards' genuinely depends on python.cmake having already run.
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE} COMPONENTS python yaml boards)
message(STATUS "VARIANT=${NORMALIZED_BOARD_TARGET}")
