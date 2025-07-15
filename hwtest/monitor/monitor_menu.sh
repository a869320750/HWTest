#!/bin/bash
# filepath: monitor_menu.sh
# 系统监控工具主菜单

TOOLS_DIR="/usr/local/bin/hw_test/monitor"

monitor_usage() {
    printf "\n========================================\n"
    echo "系统监控工具"
    echo "========================================"
    printf "\n用法: hwtest monitor [cpu|memory|thermal|power|io|network|--help]\n"
    echo "----------------------------------------"
    echo "  cpu       : CPU使用率和频率监控"
    echo "  memory    : 内存使用监控"
    echo "  thermal   : 温度监控"
    echo "  power     : 电源和功耗监控"
    echo "  io        : 磁盘I/O监控"
    echo "  network   : 网络流量监控"
    echo "  --help    : 显示本帮助信息"
    printf "\n示例:\n"
    echo "  hwtest monitor cpu                   # 监控CPU状态"
    echo "  hwtest monitor thermal               # 监控温度"
    echo "  hwtest monitor power                 # 监控功耗"
    printf "\n"
    exit 0
}

# 参数处理
if [[ $# -eq 0 || $1 == "--help" ]]; then
    monitor_usage
fi

case $1 in
    "cpu")
        exec "$TOOLS_DIR/monitor_cpu.sh" "${@:2}"
        ;;
    "memory")
        exec "$TOOLS_DIR/monitor_memory.sh" "${@:2}"
        ;;
    "thermal")
        exec "$TOOLS_DIR/monitor_thermal.sh" "${@:2}"
        ;;
    "power")
        exec "$TOOLS_DIR/monitor_power.sh" "${@:2}"
        ;;
    "io")
        exec "$TOOLS_DIR/monitor_io.sh" "${@:2}"
        ;;
    "network")
        exec "$TOOLS_DIR/monitor_network.sh" "${@:2}"
        ;;
    *)
        echo "未知命令: $1"
        monitor_usage
        ;;
esac
