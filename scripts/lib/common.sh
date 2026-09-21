#!/usr/bin/env bash
# common.sh
# Type: module (source only - do not execute directly)
# Shared utilities for shell scripts in this repo (paths, CLI checks, etc.).
#
# This file lives at scripts/lib/common.sh, so the repo root is always ../..
# from here. Callers should not recompute REPO_ROOT.

# ---- Paths ------------------------------------------------------------------

SCRIPTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR
REPO_ROOT="$(cd "${SCRIPTS_LIB_DIR}/../.." && pwd)"
readonly REPO_ROOT

# ---- Functions --------------------------------------------------------------

require_cli() {
    local cmd="$1"
    command -v "${cmd}" > /dev/null 2>&1 || {
        echo "FAIL: required CLI not on PATH: ${cmd}" >&2
        exit 1
    }
}
