#!/usr/bin/env bash
set -euo pipefail

# generate-arjuna-ao-reflect-config.sh
# Emit invert-target Graal reflect-config for Narayana/Arjuna (com.arjuna.**) so
# Oracle AO keeps names and no-arg constructors that BeanPopulator loads via
# Class.getDeclaredConstructor(). Needed when Hibernate / JTA is on the classpath.
#
# Merges into reflect-config.json (preserves existing FT entries).
#
# Usage:
#   scripts/native/generate-arjuna-ao-reflect-config.sh --module-path .

# ---- Imports ----------------------------------------------------------------

# shellcheck source=scripts/lib/ao-reflect.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/ao-reflect.sh"

# ---- Constants --------------------------------------------------------------

readonly CLASS_PREFIXES=(
    'com/arjuna/'
)

readonly REFLECT_NAME_PREFIXES=(
    'com.arjuna.'
)

# BeanPopulator reflectively newInstance()'s these; blanket com.arjuna.** OOMs/timeouts AO compile.
readonly NAME_SUFFIX_ALLOW=(
    'EnvironmentBean'
    'EnvironmentBeanMBean'
    'PropertyManager'
    'BeanPopulator'
)

# ---- Functions --------------------------------------------------------------

usage() {
    cat << 'EOF'
Usage: generate-arjuna-ao-reflect-config.sh --module-path .
EOF
}

collect_arjuna_jars_from_m2() {
    local m2="${HOME}/.m2/repository"
    find "${m2}/org/jboss/narayana" -type f -name 'narayana-jta-*.jar' \
        ! -name '*-sources.jar' ! -name '*-javadoc.jar' 2> /dev/null | sort -V | tail -5
    find "${m2}/io/quarkus" -type f -name 'quarkus-narayana-jta-*.jar' \
        ! -name '*-sources.jar' ! -name '*-javadoc.jar' 2> /dev/null | sort -V | tail -3
}

# Keep only the BeanPopulator / EnvironmentBean surface AO actually needs.
class_name_allowed() {
    local fqn="$1"
    local suffix
    for suffix in "${NAME_SUFFIX_ALLOW[@]}"; do
        [[ "${fqn}" == *"${suffix}" ]] && return 0
    done
    [[ "${fqn}" == *PropertyManager ]] && return 0
    [[ "${fqn}" == *'.BeanPopulator' ]] && return 0
    return 1
}

# ---- Main -------------------------------------------------------------------

main() {
    ao_reflect_require_tools
    local module_path
    module_path="$(ao_reflect_parse_module_path "$@")"

    local -a jars=()
    mapfile -t jars < <(
        ao_reflect_jars_from_native_source "${module_path}" \
            '*narayana*.jar' '*arjuna*.jar' \
            || true
    )
    if ((${#jars[@]} == 0)); then
        mapfile -t jars < <(collect_arjuna_jars_from_m2)
    fi
    ((${#jars[@]} > 0)) \
        || ao_reflect_die "no narayana/arjuna jars found - build the module (or native-image-source-jar) first"
    echo "Using ${#jars[@]} Narayana/Arjuna jar(s)"

    ao_reflect_enumerate_classes \
        --filter class_name_allowed \
        --prefixes "${CLASS_PREFIXES[@]}" \
        -- "${jars[@]}" \
        | ao_reflect_merge_config "${module_path}" Arjuna ctors \
            --prefixes "${REFLECT_NAME_PREFIXES[@]}"
}

main "$@"
