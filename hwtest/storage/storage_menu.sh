#!/bin/bash
# filepath: storage_menu.sh
# 存储设备测试工具主菜单

TOOLS_DIR="/usr/local/bin/hw_test/storage"

storage_usage() {
    printf "\n========================================\n"
    echo "存储设备测试工具"
    echo "========================================"
    printf "\n用法: hwtest storage [scan|speed|health|info|format|--help]\n"
    echo "----------------------------------------"
    echo "  scan      : 扫描所有存储设备"
    echo "  speed     : 存储性能测试"
    echo "  health    : 存储健康状态检查"
    echo "  info      : 显示详细存储信息"
    echo "  format    : 存储设备格式化工具"
    echo "  --help    : 显示本帮助信息"
    printf "\n示例:\n"
    echo "  hwtest storage scan                  # 扫描存储设备"
    echo "  hwtest storage speed /dev/mmcblk0   # 测试eMMC性能"
    echo "  hwtest storage health /dev/sda      # 检查硬盘健康"
    printf "\n"
    exit 0
}

# 参数处理
if [[ $# -eq 0 || $1 == "--help" ]]; then
    storage_usage
fi

case $1 in
    "scan")
        exec "$TOOLS_DIR/storage_scanner.sh" "${@:2}"
        ;;
    "speed")
        exec "$TOOLS_DIR/storage_speed.sh" "${@:2}"
        ;;
    "health")
        exec "$TOOLS_DIR/storage_health.sh" "${@:2}"
        ;;
    "info")
        exec "$TOOLS_DIR/storage_info.sh" "${@:2}"
        ;;
    "format")
        exec "$TOOLS_DIR/storage_format.sh" "${@:2}"
        ;;
    *)
        echo "未知命令: $1"
        storage_usage
        ;;
esac
