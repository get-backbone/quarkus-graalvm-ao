#!/usr/bin/env bash
set -euo pipefail

# generate-ft-ao-reflect-config.sh
# Emit invert-target Graal reflect-config for SmallRye / Quarkus / MicroProfile
# Fault Tolerance so Oracle Advanced Obfuscation keeps those names when the type
# is reachable (without -H:Preserve force-including optional Quarkus classes).
#
# Also includes persistence/CircuitBreakerNames.java when present, so AO keeps
# the FQN used by @CircuitBreakerName / Class.forName startup probes.
#
# Merges into reflect-config.json (preserves existing Redis / Arjuna entries).
#
# Usage:
#   scripts/native/generate-ft-ao-reflect-config.sh --module-path .

# ---- Imports ----------------------------------------------------------------

# shellcheck source=scripts/lib/ao-reflect.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/ao-reflect.sh"

# ---- Constants --------------------------------------------------------------

readonly CLASS_PREFIXES=(
    'io/quarkus/smallrye/faulttolerance/'
    'io/smallrye/faulttolerance/'
    'org/eclipse/microprofile/faulttolerance/'
)

readonly REFLECT_NAME_PREFIXES=(
    'io.quarkus.smallrye.faulttolerance.'
    'io.smallrye.faulttolerance.'
    'org.eclipse.microprofile.faulttolerance.'
)

# ---- Functions --------------------------------------------------------------

usage() {
    cat << 'EOF'
Usage: generate-ft-ao-reflect-config.sh --module-path .
EOF
}

collect_ft_jars_from_m2() {
    local quarkus_version="$1"
    local m2="${HOME}/.m2/repository"
    local jars=()
    local q_jar smallrye_ver mp_jar

    q_jar="${m2}/io/quarkus/quarkus-smallrye-fault-tolerance/${quarkus_version}/quarkus-smallrye-fault-tolerance-${quarkus_version}.jar"
    [[ -f "${q_jar}" ]] || ao_reflect_die "missing ${q_jar} - install deps or build the module first"
    jars+=("${q_jar}")

    smallrye_ver="$(
        find "${m2}/io/smallrye/smallrye-fault-tolerance" -mindepth 1 -maxdepth 1 -type d \
            -exec basename {} \; 2> /dev/null | sort -V | tail -1
    )"
    [[ -n "${smallrye_ver}" ]] || ao_reflect_die "no io.smallrye:smallrye-fault-tolerance in local Maven cache"

    while IFS= read -r jar; do
        jars+=("${jar}")
    done < <(
        find "${m2}/io/smallrye" -type f -path "*/${smallrye_ver}/smallrye-fault-tolerance*-${smallrye_ver}.jar" \
            ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort
    )

    mp_jar="$(
        find "${m2}/org/eclipse/microprofile/fault-tolerance/microprofile-fault-tolerance-api" \
            -type f -name 'microprofile-fault-tolerance-api-*.jar' \
            ! -name '*-sources.jar' ! -name '*-javadoc.jar' 2> /dev/null | sort -V | tail -1
    )"
    [[ -n "${mp_jar}" ]] || ao_reflect_die "missing microprofile-fault-tolerance-api jar in local Maven cache"
    jars+=("${mp_jar}")

    printf '%s\n' "${jars[@]}"
}

# ---- Main -------------------------------------------------------------------

main() {
    ao_reflect_require_tools
    local module_path
    module_path="$(ao_reflect_parse_module_path "$@")"

    # Prefer Quarkus native-image-source-jar classpath; fall back to ~/.m2.
    local -a jars=()
    mapfile -t jars < <(
        ao_reflect_jars_from_native_source "${module_path}" \
            '*fault-tolerance*.jar' '*faulttolerance*.jar' \
            || true
    )
    if ((${#jars[@]} == 0)); then
        mapfile -t jars < <(collect_ft_jars_from_m2 "$(ao_reflect_quarkus_version)")
    fi
    ((${#jars[@]} > 0)) || ao_reflect_die "no FT jars found - build the module first"
    echo "Using ${#jars[@]} FT-related jar(s)"

    local -a names=()
    mapfile -t names < <(
        ao_reflect_enumerate_classes \
            --prefixes "${CLASS_PREFIXES[@]}" \
            -- "${jars[@]}"
    )
    local cb_fqn
    cb_fqn="$(ao_reflect_discover_circuit_breaker_names "${module_path}")"
    [[ -z "${cb_fqn}" ]] || names+=("${cb_fqn}")

    local -a merge_args=(--prefixes "${REFLECT_NAME_PREFIXES[@]}")
    [[ -z "${cb_fqn}" ]] || merge_args=(--also-drop "${cb_fqn}" "${merge_args[@]}")

    printf '%s\n' "${names[@]}" \
        | ao_reflect_merge_config "${module_path}" FT plain "${merge_args[@]}"
}

main "$@"
