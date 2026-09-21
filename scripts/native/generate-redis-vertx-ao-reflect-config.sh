#!/usr/bin/env bash
set -euo pipefail

# generate-redis-vertx-ao-reflect-config.sh
# Emit invert-target Graal reflect-config for Quarkus Redis cache/client and
# Mutiny Vert.x so Oracle AO keeps CDI-visible names (e.g. io.vertx.mutiny.core.Vertx
# for quarkus-cache-redis startup wiring).
#
# Merges into reflect-config.json (preserves existing FT / Arjuna entries).
#
# Usage:
#   scripts/native/generate-redis-vertx-ao-reflect-config.sh --module-path .

# ---- Imports ----------------------------------------------------------------

# shellcheck source=scripts/lib/ao-reflect.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/ao-reflect.sh"

# ---- Constants --------------------------------------------------------------

readonly CLASS_PREFIXES=(
    'io/quarkus/cache/redis/'
    'io/quarkus/cache/runtime/'
    'io/quarkus/redis/datasource/'
    'io/quarkus/redis/runtime/'
    'io/vertx/mutiny/core/'
)

readonly REFLECT_NAME_PREFIXES=(
    'io.quarkus.cache.redis.'
    'io.quarkus.cache.runtime.'
    'io.quarkus.redis.'
    'io.vertx.mutiny.core.'
)

# ---- Functions --------------------------------------------------------------

usage() {
    cat << 'EOF'
Usage: generate-redis-vertx-ao-reflect-config.sh --module-path .
EOF
}

collect_redis_vertx_jars_from_m2() {
    local quarkus_version="$1"
    local m2="${HOME}/.m2/repository"
    local vertx_mutiny_ver jar

    for jar in \
        "${m2}/io/quarkus/quarkus-redis-client/${quarkus_version}/quarkus-redis-client-${quarkus_version}.jar" \
        "${m2}/io/quarkus/quarkus-redis-cache/${quarkus_version}/quarkus-redis-cache-${quarkus_version}.jar" \
        "${m2}/io/quarkus/quarkus-cache/${quarkus_version}/quarkus-cache-${quarkus_version}.jar" \
        "${m2}/io/quarkus/quarkus-vertx/${quarkus_version}/quarkus-vertx-${quarkus_version}.jar"; do
        [[ -f "${jar}" ]] || ao_reflect_die "missing ${jar} - install deps or build the module first"
        printf '%s\n' "${jar}"
    done

    vertx_mutiny_ver="$(
        find "${m2}/io/smallrye/reactive/smallrye-mutiny-vertx-core" -mindepth 1 -maxdepth 1 -type d \
            -exec basename {} \; 2> /dev/null | sort -V | tail -1
    )"
    [[ -n "${vertx_mutiny_ver}" ]] || ao_reflect_die "no smallrye-mutiny-vertx-core in local Maven cache"
    jar="${m2}/io/smallrye/reactive/smallrye-mutiny-vertx-core/${vertx_mutiny_ver}/smallrye-mutiny-vertx-core-${vertx_mutiny_ver}.jar"
    [[ -f "${jar}" ]] || ao_reflect_die "missing ${jar}"
    printf '%s\n' "${jar}"
}

# ---- Main -------------------------------------------------------------------

main() {
    ao_reflect_require_tools
    local module_path
    module_path="$(ao_reflect_parse_module_path "$@")"

    local -a jars=()
    mapfile -t jars < <(
        ao_reflect_jars_from_native_source "${module_path}" \
            '*redis*.jar' '*cache*.jar' '*mutiny-vertx*.jar' 'quarkus-vertx-*.jar' \
            || true
    )
    if ((${#jars[@]} == 0)); then
        mapfile -t jars < <(collect_redis_vertx_jars_from_m2 "$(ao_reflect_quarkus_version)")
    fi
    ((${#jars[@]} > 0)) \
        || ao_reflect_die "no Redis/Vertx jars found - build the module (or native-image-source-jar) first"
    echo "Using ${#jars[@]} Redis/Vertx-related jar(s)"

    ao_reflect_enumerate_classes \
        --prefixes "${CLASS_PREFIXES[@]}" \
        -- "${jars[@]}" \
        | ao_reflect_merge_config "${module_path}" Redis/Vertx plain \
            --prefixes "${REFLECT_NAME_PREFIXES[@]}"
}

main "$@"
