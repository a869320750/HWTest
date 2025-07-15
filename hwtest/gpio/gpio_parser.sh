#!/bin/bash
# filepath: gpio_parser.sh
# GPIO名称解析工具，支持 GPIOx_AY_U/D 格式

show_usage() {
    echo "用法: hwtest gpio parse <GPIO名称>"
    echo ""
    echo "支持格式: GPIOx_AY_U/D"
    echo "  x: bank号 (0-4)"
    echo "  A: 组字母 (A-H)"
    echo "  Y: 组内编号 (0-7)"
    echo "  U/D: 上拉/下拉"
    echo ""
    echo "示例:"
    echo "  hwtest gpio parse GPIO3_D2_D"
    echo "  hwtest gpio parse GPIO0_A5_U"
    echo "  hwtest gpio parse GPIO4_C1_D"
}

parse_gpio_name() {
    local gpio_name="$1"
    
    # 转换为大写
    gpio_name=$(echo "$gpio_name" | tr '[:lower:]' '[:upper:]')
    
    # 正则匹配 GPIOx_AY_U/D
    if [[ ! "$gpio_name" =~ ^GPIO([0-4])_([A-H])([0-7])_([UD])$ ]]; then
        echo "错误: GPIO名称格式不正确"
        echo "正确格式: GPIOx_AY_U/D"
        echo "示例: GPIO3_D2_D"
        return 1
    fi
    
    local bank="${BASH_REMATCH[1]}"
    local letter="${BASH_REMATCH[2]}"
    local num="${BASH_REMATCH[3]}"
    local pull_suffix="${BASH_REMATCH[4]}"
    
    # 计算letter的索引 (A=0, B=1, ..., H=7)
    local letter_idx
    case "$letter" in
        A) letter_idx=0 ;;
        B) letter_idx=1 ;;
        C) letter_idx=2 ;;
        D) letter_idx=3 ;;
        E) letter_idx=4 ;;
        F) letter_idx=5 ;;
        G) letter_idx=6 ;;
        H) letter_idx=7 ;;
    esac
    
    # 计算pin号: letter_idx * 8 + num
    local pin=$((letter_idx * 8 + num))
    
    # 计算sysfs编号: bank * 32 + pin
    local gpio_num=$((bank * 32 + pin))
    
    # 解析pull类型
    local pull_type
    case "$pull_suffix" in
        U) pull_type="up" ;;
        D) pull_type="down" ;;
    esac
    
    echo "=========================================="
    echo "GPIO名称解析结果: $gpio_name"
    echo "=========================================="
    echo "Bank号:     $bank"
    echo "组:         $letter (索引: $letter_idx)"
    echo "组内编号:   $num"
    echo "Pin号:      $pin"
    echo "SysFS编号:  $gpio_num"
    echo "上下拉:     $pull_type"
    echo ""
    echo "设备树配置:"
    echo "----------------------------------------"
    local label=$(echo "$gpio_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    local pull_cfg
    case "$pull_type" in
        up)   pull_cfg="&pcfg_pull_up" ;;
        down) pull_cfg="&pcfg_pull_down" ;;
        *)    pull_cfg="&pcfg_pull_none" ;;
    esac
    
    echo "${label}-out: ${label}-out {"
    echo "    rockchip,pins = <$bank $pin RK_FUNC_GPIO $pull_cfg>;"
    echo "};"
    echo ""
    echo "SysFS操作命令:"
    echo "----------------------------------------"
    echo "# 导出GPIO"
    echo "echo $gpio_num > /sys/class/gpio/export"
    echo ""
    echo "# 设置为输出模式"
    echo "echo out > /sys/class/gpio/gpio$gpio_num/direction"
    echo ""
    echo "# 设置高电平"
    echo "echo 1 > /sys/class/gpio/gpio$gpio_num/value"
    echo ""
    echo "# 设置低电平"
    echo "echo 0 > /sys/class/gpio/gpio$gpio_num/value"
    echo ""
    echo "# 读取当前值"
    echo "cat /sys/class/gpio/gpio$gpio_num/value"
    echo ""
    echo "# 取消导出"
    echo "echo $gpio_num > /sys/class/gpio/unexport"
    echo "=========================================="
}

# 检查参数
if [[ $# -eq 0 ]]; then
    echo "错误: 请提供GPIO名称"
    show_usage
    exit 1
fi

if [[ $1 == "--help" ]]; then
    show_usage
    exit 0
fi

# 解析GPIO名称
parse_gpio_name "$1"
