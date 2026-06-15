#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUBMODULES=(
    UnitreeSimEnv
    UnitreeSimCtrl
    SdkEventBridge
    UnitreeSdkCtrl
)

source_ros() {
    # ROS setup scripts reference unset variables; disable nounset while sourcing.
    set +u
    if [[ -n "${ROS_DISTRO:-}" ]] && [[ -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]]; then
        # shellcheck source=/dev/null
        source "/opt/ros/${ROS_DISTRO}/setup.bash"
    elif [[ -f "/opt/ros/humble/setup.bash" ]]; then
        # shellcheck source=/dev/null
        source "/opt/ros/humble/setup.bash"
    fi
    set -u
}

cleanup_root_workspace() {
    local artifact
    for artifact in build install log logs; do
        if [[ -e "${ROOT_DIR}/${artifact}" ]]; then
            echo "Removing stray root ${artifact}/ (colcon artifacts belong in submodules)"
            rm -rf "${ROOT_DIR:?}/${artifact}"
        fi
    done
}

build_submodule() {
    local name="$1"
    local dir="${ROOT_DIR}/${name}"

    if [[ ! -f "${dir}/build.sh" ]]; then
        echo "[ERROR] Missing build.sh in ${name}" >&2
        exit 1
    fi

    echo "==================================================================="
    echo "Building ${name}"
    echo "==================================================================="
    (
        cd "${dir}"
        bash ./build.sh
    )
}

main() {
    cleanup_root_workspace
    source_ros

    for name in "${SUBMODULES[@]}"; do
        build_submodule "${name}"
    done

    cleanup_root_workspace

    echo "==================================================================="
    echo "All submodules built successfully."
    echo "==================================================================="
}

main "$@"
