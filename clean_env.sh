#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Stop Gazebo and UnitreeSim-related ROS processes for a clean restart.

Options:
  -h, --help       Show this help message
  --prelaunch      Kill only stale Gazebo/ROS nodes from a previous run.
                   Safe to call from gazebo.launch.py while other launch
                   nodes are already starting.

Default (full clean):
  - Gazebo (gzserver, gzclient)
  - Stale robot_state_publisher nodes (prevents controller_manager conflicts)
  - UnitreeSim launch helpers (b2_sim, rl_sim, spawn_entity, etc.)
EOF
}

kill_stale_sim_nodes() {
    kill_by_name gzserver
    kill_by_name gzclient
    kill_by_name robot_state_publisher
    kill_by_name rviz2
}

kill_unitree_sim_processes() {
    kill_by_pattern "${ROOT_DIR}/UnitreeSimEnv/.*ros2 launch"
    kill_by_pattern "${ROOT_DIR}/UnitreeSimEnv/.*spawn_entity.py"
    kill_by_pattern "${ROOT_DIR}/UnitreeSimEnv/.*load_joint_state_broadcaster"
    kill_by_pattern "${ROOT_DIR}/UnitreeSimEnv/.*dog_odom_publisher"
    kill_by_pattern "${ROOT_DIR}/UnitreeSimCtrl/.*rl_sim"
    kill_by_pattern "${ROOT_DIR}/UnitreeSimCtrl/.*ros2 run"
    kill_by_pattern "${ROOT_DIR}/SdkEventBridge/"
    kill_by_pattern "${ROOT_DIR}/UnitreeSdkCtrl/"
}

kill_by_name() {
    local name="$1"
    if ! pgrep -x "${name}" >/dev/null 2>&1; then
        return 0
    fi

    echo "[clean] stopping ${name}..."
    killall "${name}" 2>/dev/null || true
    sleep 0.5
    killall -9 "${name}" 2>/dev/null || true
}

kill_by_pattern() {
    local pattern="$1"
    if ! pgrep -f "${pattern}" >/dev/null 2>&1; then
        return 0
    fi

    echo "[clean] stopping processes matching: ${pattern}"
    pkill -f "${pattern}" 2>/dev/null || true
    sleep 0.5
    pkill -9 -f "${pattern}" 2>/dev/null || true
}

main() {
    local mode="full"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --prelaunch)
                mode="prelaunch"
                shift
                ;;
            *)
                echo "[ERROR] Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
    done

    echo "==================================================================="
    if [[ "${mode}" == "prelaunch" ]]; then
        echo "Cleaning stale simulation processes (prelaunch)"
    else
        echo "Cleaning simulation environment"
    fi
    echo "==================================================================="

    kill_stale_sim_nodes

    if [[ "${mode}" == "full" ]]; then
        kill_unitree_sim_processes
    fi

    sleep 1

    echo "==================================================================="
    echo "Environment clean."
    echo "==================================================================="
}

main "$@"
