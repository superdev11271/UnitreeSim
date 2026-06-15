#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUBMODULES=(
    UnitreeSimEnv
    UnitreeSimCtrl
    SdkEventBridge
    UnitreeSdkCtrl
)

ARTIFACTS=(build install log logs)

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Remove build artifacts from all submodules and the repo root.

Options:
  -h, --help    Show this help message

Removes these directories when present:
  build/ install/ log/ logs/
EOF
}

remove_artifacts() {
    local base_dir="$1"
    local label="$2"
    local artifact removed=false

    for artifact in "${ARTIFACTS[@]}"; do
        if [[ -e "${base_dir}/${artifact}" ]]; then
            rm -rf "${base_dir:?}/${artifact}"
            echo "Removed ${label}/${artifact}/"
            removed=true
        fi
    done

    if [[ "${removed}" == false ]]; then
        echo "No artifacts in ${label}"
    fi
}

clean_ros_symlinks() {
    local dir="$1"
    local package_dir

    if [[ ! -d "${dir}/src" ]]; then
        return 0
    fi

    while IFS= read -r -d '' package_dir; do
        package_dir="$(dirname "${package_dir}")"
        if [[ -L "${package_dir}/package.xml" ]]; then
            rm -f "${package_dir}/package.xml"
            echo "Removed symlink ${package_dir#"${ROOT_DIR}/"}/package.xml"
        fi
    done < <(find "${dir}/src" -name "package.ros2.xml" -print0 2>/dev/null || true)
}

main() {
    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        "")
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac

    echo "==================================================================="
    echo "Cleaning all submodules"
    echo "==================================================================="

    for name in "${SUBMODULES[@]}"; do
        local dir="${ROOT_DIR}/${name}"
        if [[ ! -d "${dir}" ]]; then
            echo "[WARNING] Submodule not found: ${name}" >&2
            continue
        fi

        echo "-------------------------------------------------------------------"
        echo "Cleaning ${name}"
        echo "-------------------------------------------------------------------"
        remove_artifacts "${dir}" "${name}"
        clean_ros_symlinks "${dir}"
    done

    echo "-------------------------------------------------------------------"
    echo "Cleaning repo root"
    echo "-------------------------------------------------------------------"
    remove_artifacts "${ROOT_DIR}" "UnitreeSim"

    echo "==================================================================="
    echo "Clean completed."
    echo "==================================================================="
}

main "$@"
