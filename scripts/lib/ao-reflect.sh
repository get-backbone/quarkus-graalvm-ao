#!/usr/bin/env bash
# ao-reflect.sh
# Type: module (source only - do not execute directly)
# Shared helpers for invert-target Advanced Obfuscation reflect-config generators.
#
# Override before sourcing if needed:
#   AO_REFLECT_NI_GROUP  Graal native-image resource group (default: io.backbone.demo)

# ---- Imports ----------------------------------------------------------------

# shellcheck source=scripts/lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# ---- Constants --------------------------------------------------------------

: "${AO_REFLECT_NI_GROUP:=io.backbone.demo}"

# ---- Functions --------------------------------------------------------------

ao_reflect_die() {
    echo "FAIL: $*" >&2
    exit 1
}

ao_reflect_require_tools() {
    require_cli jq
    require_cli jar
    require_cli find
    require_cli sort
}

# Parse --module-path / -h from "$@"; print module path (default ".") on stdout.
ao_reflect_parse_module_path() {
    local module_path=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --module-path)
                module_path="${2:-}"
                shift 2
                ;;
            -h | --help)
                if declare -F usage > /dev/null; then
                    usage
                else
                    echo "Usage: $0 --module-path ."
                fi
                exit 0
                ;;
            *)
                ao_reflect_die "unknown arg: $1"
                ;;
        esac
    done

    module_path="${module_path:-.}"
    ao_reflect_validate_module_path "${module_path}"
    printf '%s\n' "${module_path}"
}

ao_reflect_validate_module_path() {
    local module_path="$1"
    [[ -n "${REPO_ROOT:-}" ]] || ao_reflect_die "REPO_ROOT is not set"
    if [[ "${module_path}" == "." ]]; then
        [[ -d "${REPO_ROOT}" ]] || ao_reflect_die "repo root missing: ${REPO_ROOT}"
    else
        [[ -d "${REPO_ROOT}/${module_path}" ]] \
            || ao_reflect_die "module path not found: ${module_path}"
    fi
}

ao_reflect_module_root() {
    local module_path="$1"
    if [[ "${module_path}" == "." ]]; then
        printf '%s\n' "${REPO_ROOT}"
    else
        printf '%s\n' "${REPO_ROOT}/${module_path}"
    fi
}

ao_reflect_service_name() {
    local module_path="$1"
    if [[ "${module_path}" == "." ]]; then
        basename "${REPO_ROOT}"
    else
        basename "${module_path}"
    fi
}

ao_reflect_config_path() {
    local module_path="$1"
    local module_root service_name
    module_root="$(ao_reflect_module_root "${module_path}")"
    service_name="$(ao_reflect_service_name "${module_path}")"
    printf '%s\n' \
        "${module_root}/src/main/resources/META-INF/native-image/${AO_REFLECT_NI_GROUP}/${service_name}/reflect-config.json"
}

ao_reflect_quarkus_version() {
    "${REPO_ROOT}/mvnw" -f "${REPO_ROOT}/pom.xml" help:evaluate \
        -Dexpression=quarkus.platform.version -q -DforceStdout
}

# Print path to …/target/*-native-image-source-jar/lib, or return 1.
ao_reflect_native_lib_dir() {
    local module_path="$1"
    local module_root candidate
    module_root="$(ao_reflect_module_root "${module_path}")"
    for candidate in "${module_root}"/target/*-native-image-source-jar/lib; do
        if [[ -d "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

# Find jars under native-image-source-jar/lib matching -name globs (args after module_path).
# Returns 1 if the lib dir is missing or no jars match.
ao_reflect_jars_from_native_source() {
    local module_path="$1"
    shift
    local lib_dir
    local -a find_names=()
    local pattern

    lib_dir="$(ao_reflect_native_lib_dir "${module_path}")" || return 1
    [[ $# -gt 0 ]] || ao_reflect_die "ao_reflect_jars_from_native_source: need at least one -name glob"

    for pattern in "$@"; do
        find_names+=(-o -name "${pattern}")
    done
    # Drop the leading -o from the first pattern.
    find_names=("${find_names[@]:1}")

    find "${lib_dir}" -maxdepth 1 -type f \( "${find_names[@]}" \) \
        ! -name '*-sources.jar' ! -name '*-javadoc.jar' | sort
}

# Enumerate FQNs from jars whose .class path starts with any given prefix.
# Usage:
#   ao_reflect_enumerate_classes [--filter FN] --prefixes P... -- jar...
# FN (optional) accepts an FQN and returns 0 to keep the class.
ao_reflect_enumerate_classes() {
    local filter_fn=""
    local -a prefixes=()
    local -a jars=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --filter)
                filter_fn="${2:-}"
                shift 2
                ;;
            --prefixes)
                shift
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    prefixes+=("$1")
                    shift
                done
                ;;
            --)
                shift
                jars=("$@")
                break
                ;;
            *)
                ao_reflect_die "ao_reflect_enumerate_classes: unexpected arg: $1"
                ;;
        esac
    done

    ((${#prefixes[@]} > 0)) || ao_reflect_die "ao_reflect_enumerate_classes: need --prefixes"
    ((${#jars[@]} > 0)) || ao_reflect_die "ao_reflect_enumerate_classes: need jars after --"

    local jar entry fqn prefix
    for jar in "${jars[@]}"; do
        [[ -f "${jar}" ]] || continue
        while IFS= read -r entry; do
            [[ "${entry}" == *.class ]] || continue
            [[ "${entry}" == *module-info.class ]] && continue
            for prefix in "${prefixes[@]}"; do
                [[ "${entry}" == "${prefix}"* ]] || continue
                fqn="${entry%.class}"
                fqn="${fqn//\//.}"
                if [[ -n "${filter_fn}" ]]; then
                    "${filter_fn}" "${fqn}" || continue 2
                fi
                printf '%s\n' "${fqn}"
                continue 2
            done
        done < <(jar tf "${jar}")
    done | sort -u
}

ao_reflect_entry_json_plain() {
    local name="$1"
    jq -n --arg name "${name}" '{
      name: $name,
      condition: {typeReachable: $name}
    }'
}

ao_reflect_entry_json_ctors() {
    local name="$1"
    jq -n --arg name "${name}" '{
      name: $name,
      allDeclaredConstructors: true,
      allPublicConstructors: true,
      condition: {typeReachable: $name}
    }'
}

# Optional …/persistence/CircuitBreakerNames.java → FQN (empty if absent).
ao_reflect_discover_circuit_breaker_names() {
    local module_path="$1"
    local module_root src_root java_file rel
    module_root="$(ao_reflect_module_root "${module_path}")"
    src_root="${module_root}/src/main/java"
    [[ -d "${src_root}" ]] || return 0
    java_file="$(
        find "${src_root}" \
            -name 'CircuitBreakerNames.java' \
            -path '*/persistence/CircuitBreakerNames.java' \
            -print -quit 2> /dev/null || true
    )"
    [[ -n "${java_file}" ]] || return 0
    rel="${java_file#"${src_root}"/}"
    rel="${rel%.java}"
    printf '%s\n' "${rel//\//.}"
}

# Merge invert-target entries into the module reflect-config.json.
# Drops existing entries whose names start with any --prefixes value,
# and optionally one exact FQN (--also-drop, e.g. CircuitBreakerNames).
#
# Usage:
#   ao_reflect_merge_config MODULE_PATH LABEL STYLE [--also-drop FQN] --prefixes P...
#   class FQNs on stdin
# STYLE: plain | ctors
ao_reflect_merge_config() {
    local module_path="$1"
    local label="$2"
    local style="$3"
    shift 3
    local also_drop=""
    local -a replace_prefixes=()
    local out_file count tmp_new tmp_merged existing entry_fn
    local -a class_names=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --also-drop)
                also_drop="${2:-}"
                shift 2
                ;;
            --prefixes)
                shift
                while [[ $# -gt 0 && "$1" != --* ]]; do
                    replace_prefixes+=("$1")
                    shift
                done
                ;;
            *)
                ao_reflect_die "ao_reflect_merge_config: unexpected arg: $1"
                ;;
        esac
    done

    ((${#replace_prefixes[@]} > 0)) || ao_reflect_die "ao_reflect_merge_config: need --prefixes"

    case "${style}" in
        plain) entry_fn=ao_reflect_entry_json_plain ;;
        ctors) entry_fn=ao_reflect_entry_json_ctors ;;
        *) ao_reflect_die "unknown entry style: ${style} (want plain|ctors)" ;;
    esac

    mapfile -t class_names
    count="${#class_names[@]}"
    ((count > 0)) || ao_reflect_die "zero ${label} classes found - check jars / classpath"

    out_file="$(ao_reflect_config_path "${module_path}")"
    mkdir -p "$(dirname "${out_file}")"

    tmp_new="$(mktemp)"
    tmp_merged="$(mktemp)"
    printf '%s\n' "${class_names[@]}" | while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        "${entry_fn}" "${name}"
    done | jq -s '.' > "${tmp_new}"

    if [[ -f "${out_file}" ]]; then
        existing="${out_file}"
    else
        existing="$(mktemp)"
        echo '[]' > "${existing}"
    fi

    jq -s \
        --argjson prefixes "$(printf '%s\n' "${replace_prefixes[@]}" | jq -R . | jq -s '.')" \
        --arg drop "${also_drop}" '
      (.[0] | map(select(
        .name as $n
        | ($prefixes | any(. as $p | ($n | startswith($p))) | not)
          and ($drop == "" or $n != $drop)
      )))
      + .[1]
      | sort_by(.name)
    ' "${existing}" "${tmp_new}" > "${tmp_merged}"

    mv "${tmp_merged}" "${out_file}"
    rm -f "${tmp_new}"
    [[ "${existing}" == "${out_file}" ]] || rm -f "${existing}"

    if [[ -n "${also_drop}" ]]; then
        echo "Merged ${count} invert-target ${label} entries (incl. ${also_drop}) -> ${out_file}"
    else
        echo "Merged ${count} invert-target ${label} entries -> ${out_file}"
    fi
}
