#!/bin/bash
# filepath: uart_menu.sh
# UART/串口调试工具主菜单

TOOLS_DIR="/usr/local/bin/hw_test/uart"

uart_usage() {
    printf "\n========================================\n"
    echo "UART/串口调试工具"
    echo "========================================"
    printf "\n用法: hwtest uart [monitor|send|loopback|scan|config|--help]\n"
    echo "----------------------------------------"
    echo "  monitor   : 监控所有串口数据"
    echo "  send      : 向指定串口发送数据"
    echo "  loopback  : 串口环回测试"
    echo "  scan      : 扫描可用串口"
    echo "  config    : 配置串口参数"
    echo "  --help    : 显示本帮助信息"
    printf "\n示例:\n"
    echo "  hwtest uart monitor          # 监控所有串口"
    echo "  hwtest uart send /dev/ttyS0  # 向ttyS0发送测试数据"
    echo "  hwtest uart scan             # 扫描可用串口"
    printf "\n"
    exit 0
}

# 参数处理
if [[ $# -eq 0 || $1 == "--help" ]]; then
    uart_usage
fi

case $1 in
    "monitor")
        exec "$TOOLS_DIR/uart_monitor.sh" "${@:2}"
        ;;
    "send")
        exec "$TOOLS_DIR/uart_sender.sh" "${@:2}"
        ;;
    "loopback")
        exec "$TOOLS_DIR/uart_loopback.sh" "${@:2}"
        ;;
    "scan")
        exec "$TOOLS_DIR/uart_scanner.sh" "${@:2}"
        ;;
    "config")
        exec "$TOOLS_DIR/uart_config.sh" "${@:2}"
        ;;
    *)
        echo "未知命令: $1"
        uart_usage
        ;;
esac
