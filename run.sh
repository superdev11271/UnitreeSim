#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUBMODULES=(
    UnitreeSimEnv
    UnitreeSimCtrl
    SdkEventBridge
    UnitreeSdkCtrl
)

NETWORK_INTERFACE="${NETWORK_INTERFACE:-eth0}"
GAZEBO_STARTUP_SEC="${GAZEBO_STARTUP_SEC:-10}"
STARTUP_GAP_SEC="${STARTUP_GAP_SEC:-2}"

PIDS=()

usage() {
    cat <<EOF
Usage: $0 [networkInterface] [unitreeSdkCtrl args...]

Starts all submodules in order:
  1. UnitreeSimEnv
  2. UnitreeSimCtrl
  3. SdkEventBridge
  4. UnitreeSdkCtrl

Environment:
  NETWORK_INTERFACE   DDS network interface (default: eth0)
  GAZEBO_STARTUP_SEC  Seconds to wait after Gazebo starts (default: 10)
  STARTUP_GAP_SEC     Seconds between later submodule starts (default: 2)

Examples:
  $0
  $0 eth0
  $0 lo --timeout-ms 1500
EOF
}

cleanup() {
    local pid
    for pid in "${PIDS[@]}"; do
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null || true
}

trap cleanup EXIT INT TERM

start_submodule() {
    local name="$1"
    shift
    local dir="${ROOT_DIR}/${name}"

    if [[ ! -f "${dir}/run.sh" ]]; then
        echo "[ERROR] Missing run.sh in ${name}" >&2
        exit 1
    fi

    echo "Starting ${name}..."
    local pid
    (
        cd "${dir}"
        exec bash ./run.sh "$@"
    ) &
    pid=$!
    PIDS+=("${pid}")
    echo "  PID ${pid}"
}

main() {
    local sdk_ctrl_args=()

    case "${1:-}" in
        -h|--help)
            usage
            exit 0
            ;;
        "")
            ;;
        *)
            NETWORK_INTERFACE="$1"
            shift
            sdk_ctrl_args=("$@")
            ;;
    esac

    if [[ -x "${ROOT_DIR}/clean_env.sh" ]]; then
        bash "${ROOT_DIR}/clean_env.sh"
    fi

    start_submodule UnitreeSimEnv
    sleep "${GAZEBO_STARTUP_SEC}"

    start_submodule UnitreeSimCtrl
    sleep "${STARTUP_GAP_SEC}"

    start_submodule SdkEventBridge "${NETWORK_INTERFACE}"
    sleep "${STARTUP_GAP_SEC}"

    start_submodule UnitreeSdkCtrl "${NETWORK_INTERFACE}" "${sdk_ctrl_args[@]}"

    echo "All submodules running. Press Ctrl+C to stop."
    wait
}

main "$@"
