#!/bin/bash
# filepath: gpio_menu.sh
# GPIO调试工具主菜单

TOOLS_DIR="/usr/local/bin/hw_test/gpio"

gpio_usage() {
    printf "\n========================================\n"
    echo "GPIO调试工具"
    echo "========================================"
    printf "\n用法: hwtest gpio [set|get|export|unexport|scan|parse|batch|--help]\n"
    echo "----------------------------------------"
    echo "  set       : 设置GPIO状态(高/低电平)"
    echo "  get       : 读取GPIO状态"
    echo "  export    : 导出GPIO到sysfs"
    echo "  unexport  : 从sysfs移除GPIO"
    echo "  scan      : 扫描已导出的GPIO"
    echo "  parse     : 解析GPIO名称(如GPIO3_D2_D)"
    echo "  batch     : 批量GPIO操作"
    echo "  --help    : 显示本帮助信息"
    printf "\n示例:\n"
    echo "  hwtest gpio parse GPIO3_D2_D         # 解析GPIO名称"
    echo "  hwtest gpio set 125 1                # 设置GPIO 125为高电平"
    echo "  hwtest gpio get 125                  # 读取GPIO 125状态"
    echo "  hwtest gpio scan                     # 扫描所有已导出GPIO"
    echo "  hwtest gpio batch --generate         # 生成批量配置模板"
    printf "\n"
    exit 0
}

# 参数处理
if [[ $# -eq 0 || $1 == "--help" ]]; then
    gpio_usage
fi

case $1 in
    "set")
        exec "$TOOLS_DIR/gpio_setter.sh" "${@:2}"
        ;;
    "get")
        exec "$TOOLS_DIR/gpio_getter.sh" "${@:2}"
        ;;
    "export")
        exec "$TOOLS_DIR/gpio_export.sh" "${@:2}"
        ;;
    "unexport")
        exec "$TOOLS_DIR/gpio_unexport.sh" "${@:2}"
        ;;
    "scan")
        exec "$TOOLS_DIR/gpio_scanner.sh" "${@:2}"
        ;;
    "parse")
        exec "$TOOLS_DIR/gpio_parser.sh" "${@:2}"
        ;;
    "batch")
        exec "$TOOLS_DIR/gpio_batch.sh" "${@:2}"
        ;;
    *)
        echo "未知命令: $1"
        gpio_usage
        ;;
esac
