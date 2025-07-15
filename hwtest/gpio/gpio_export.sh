#!/bin/bash
# filepath: gpio_export.sh
# GPIO导出工具

show_usage() {
    echo "用法: hwtest gpio export <GPIO编号|GPIO名称> [选项]"
    echo ""
    echo "参数:"
    echo "  GPIO编号     : sysfs GPIO编号 (如: 125)"
    echo "  GPIO名称     : Rockchip GPIO名称 (如: GPIO3_D2_D)"
    echo ""
    echo "选项:"
    echo "  -d, --direction <dir>  导出后设置方向 (in/out)"
    echo "  -v, --value <val>      导出后设置值 (0/1，需要direction=out)"
    echo "  -f, --force            强制导出(如果已存在则先取消导出)"
    echo "  --help                 显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest gpio export 125              # 导出GPIO 125"
    echo "  hwtest gpio export GPIO3_D2_D       # 导出GPIO3_D2_D"
    echo "  hwtest gpio export 125 -d out -v 1  # 导出并设置为输出高电平"
    echo "  hwtest gpio export 125 --force      # 强制导出"
}

# 解析GPIO名称为编号
parse_gpio_name_to_num() {
    local gpio_name="$1"
    
    # 转换为大写
    gpio_name=$(echo "$gpio_name" | tr '[:lower:]' '[:upper:]')
    
    # 正则匹配 GPIOx_AY_U/D
    if [[ "$gpio_name" =~ ^GPIO([0-4])_([A-H])([0-7])_?([UD]?)$ ]]; then
        local bank="${BASH_REMATCH[1]}"
        local letter="${BASH_REMATCH[2]}"
        local num="${BASH_REMATCH[3]}"
        
        # 计算letter的索引
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
        
        # 计算pin号和sysfs编号
        local pin=$((letter_idx * 8 + num))
        local gpio_num=$((bank * 32 + pin))
        
        echo "$gpio_num"
        return 0
    else
        echo ""
        return 1
    fi
}

# 检查GPIO是否已导出
is_gpio_exported() {
    local gpio_num="$1"
    [[ -d "/sys/class/gpio/gpio$gpio_num" ]]
}

# 取消导出GPIO
unexport_gpio() {
    local gpio_num="$1"
    
    if ! is_gpio_exported "$gpio_num"; then
        return 0  # 已经没有导出
    fi
    
    if echo "$gpio_num" > /sys/class/gpio/unexport 2>/dev/null; then
        echo "GPIO $gpio_num 已取消导出"
        return 0
    else
        echo "警告: 无法取消导出GPIO $gpio_num"
        return 1
    fi
}

# 导出GPIO
export_gpio() {
    local gpio_num="$1"
    local force="$2"
    
    if is_gpio_exported "$gpio_num"; then
        if [[ "$force" == "true" ]]; then
            echo "GPIO $gpio_num 已存在，强制重新导出..."
            unexport_gpio "$gpio_num"
            sleep 0.1  # 短暂等待
        else
            echo "GPIO $gpio_num 已经导出"
            return 0
        fi
    fi
    
    if echo "$gpio_num" > /sys/class/gpio/export 2>/dev/null; then
        echo "GPIO $gpio_num 导出成功"
        return 0
    else
        echo "错误: GPIO $gpio_num 导出失败"
        return 1
    fi
}

# 设置GPIO方向
set_gpio_direction() {
    local gpio_num="$1"
    local direction="$2"
    
    if echo "$direction" > "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null; then
        echo "GPIO $gpio_num 方向设置为: $direction"
        return 0
    else
        echo "错误: 无法设置GPIO $gpio_num 方向为 $direction"
        return 1
    fi
}

# 设置GPIO值
set_gpio_value() {
    local gpio_num="$1"
    local value="$2"
    
    if echo "$value" > "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null; then
        local level_name
        case "$value" in
            0) level_name="低电平" ;;
            1) level_name="高电平" ;;
            *) level_name="值$value" ;;
        esac
        echo "GPIO $gpio_num 设置为: $level_name ($value)"
        return 0
    else
        echo "错误: 无法设置GPIO $gpio_num 值为 $value"
        return 1
    fi
}

# 默认参数
DIRECTION=""
VALUE=""
FORCE=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--direction)
            DIRECTION="$2"
            shift 2
            ;;
        -v|--value)
            VALUE="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$GPIO_INPUT" ]]; then
                GPIO_INPUT="$1"
            else
                echo "未知参数: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查必要参数
if [[ -z "$GPIO_INPUT" ]]; then
    echo "错误: 请提供GPIO编号或名称"
    show_usage
    exit 1
fi

# 验证参数
if [[ -n "$DIRECTION" && "$DIRECTION" != "in" && "$DIRECTION" != "out" ]]; then
    echo "错误: 方向必须是 in 或 out"
    exit 1
fi

if [[ -n "$VALUE" && "$VALUE" != "0" && "$VALUE" != "1" ]]; then
    echo "错误: 值必须是 0 或 1"
    exit 1
fi

if [[ -n "$VALUE" && "$DIRECTION" != "out" ]]; then
    echo "错误: 设置值需要方向为 out"
    exit 1
fi

# 解析GPIO输入
if [[ "$GPIO_INPUT" =~ ^[0-9]+$ ]]; then
    # 数字输入，直接使用
    GPIO_NUM="$GPIO_INPUT"
else
    # GPIO名称，需要解析
    GPIO_NUM=$(parse_gpio_name_to_num "$GPIO_INPUT")
    if [[ -z "$GPIO_NUM" ]]; then
        echo "错误: 无法解析GPIO名称: $GPIO_INPUT"
        echo "支持格式: GPIOx_AY_U/D (如: GPIO3_D2_D)"
        exit 1
    fi
    echo "解析 $GPIO_INPUT -> GPIO编号: $GPIO_NUM"
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以操作GPIO"
    echo ""
fi

echo "=========================================="
echo "导出GPIO: $GPIO_NUM"
if [[ -n "$DIRECTION" ]]; then
    echo "方向: $DIRECTION"
fi
if [[ -n "$VALUE" ]]; then
    echo "值: $VALUE"
fi
echo "=========================================="

# 导出GPIO
if ! export_gpio "$GPIO_NUM" "$FORCE"; then
    exit 1
fi

# 设置方向
if [[ -n "$DIRECTION" ]]; then
    if ! set_gpio_direction "$GPIO_NUM" "$DIRECTION"; then
        exit 1
    fi
fi

# 设置值
if [[ -n "$VALUE" ]]; then
    if ! set_gpio_value "$GPIO_NUM" "$VALUE"; then
        exit 1
    fi
fi

echo "=========================================="
echo "GPIO导出完成"

# 显示当前状态
if [[ -d "/sys/class/gpio/gpio$GPIO_NUM" ]]; then
    local value direction
    value=$(cat "/sys/class/gpio/gpio$GPIO_NUM/value" 2>/dev/null || echo "unknown")
    direction=$(cat "/sys/class/gpio/gpio$GPIO_NUM/direction" 2>/dev/null || echo "unknown")
    echo "当前状态: 方向=$direction, 值=$value"
fi
