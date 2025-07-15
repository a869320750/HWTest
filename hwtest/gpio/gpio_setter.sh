#!/bin/bash
# filepath: gpio_setter.sh
# GPIO设置工具

show_usage() {
    echo "用法: hwtest gpio set <GPIO编号|GPIO名称> <值> [选项]"
    echo ""
    echo "参数:"
    echo "  GPIO编号     : sysfs GPIO编号 (如: 125)"
    echo "  GPIO名称     : Rockchip GPIO名称 (如: GPIO3_D2_D)"
    echo "  值           : 0(低电平) 或 1(高电平)"
    echo ""
    echo "选项:"
    echo "  -d, --direction <dir>  设置方向 (in/out，默认: out)"
    echo "  -a, --auto-export      自动导出GPIO"
    echo "  -v, --verify           设置后验证结果"
    echo "  --help                 显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest gpio set 125 1              # 设置GPIO 125为高电平"
    echo "  hwtest gpio set GPIO3_D2_D 0       # 设置GPIO3_D2_D为低电平"
    echo "  hwtest gpio set 125 1 --verify     # 设置并验证"
    echo "  hwtest gpio set 125 1 -a           # 自动导出并设置"
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

# 导出GPIO
export_gpio() {
    local gpio_num="$1"
    
    if is_gpio_exported "$gpio_num"; then
        echo "GPIO $gpio_num 已经导出"
        return 0
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

# 验证GPIO值
verify_gpio_value() {
    local gpio_num="$1"
    local expected="$2"
    
    local actual
    if actual=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null); then
        if [[ "$actual" == "$expected" ]]; then
            echo "✅ 验证成功: GPIO $gpio_num = $actual"
            return 0
        else
            echo "❌ 验证失败: GPIO $gpio_num 期望=$expected, 实际=$actual"
            return 1
        fi
    else
        echo "❌ 验证失败: 无法读取GPIO $gpio_num"
        return 1
    fi
}

# 默认参数
DIRECTION="out"
AUTO_EXPORT=false
VERIFY=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--direction)
            DIRECTION="$2"
            shift 2
            ;;
        -a|--auto-export)
            AUTO_EXPORT=true
            shift
            ;;
        -v|--verify)
            VERIFY=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$GPIO_INPUT" ]]; then
                GPIO_INPUT="$1"
            elif [[ -z "$VALUE" ]]; then
                VALUE="$1"
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
if [[ -z "$GPIO_INPUT" || -z "$VALUE" ]]; then
    echo "错误: 缺少必要参数"
    show_usage
    exit 1
fi

# 验证值参数
if [[ "$VALUE" != "0" && "$VALUE" != "1" ]]; then
    echo "错误: 值必须是 0 或 1"
    exit 1
fi

# 验证方向参数
if [[ "$DIRECTION" != "in" && "$DIRECTION" != "out" ]]; then
    echo "错误: 方向必须是 in 或 out"
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
echo "设置GPIO: $GPIO_NUM"
echo "方向: $DIRECTION"
echo "值: $VALUE"
echo "=========================================="

# 自动导出
if [[ "$AUTO_EXPORT" == "true" ]]; then
    export_gpio "$GPIO_NUM" || exit 1
fi

# 检查GPIO是否已导出
if ! is_gpio_exported "$GPIO_NUM"; then
    echo "错误: GPIO $GPIO_NUM 未导出，请先导出或使用 --auto-export 选项"
    echo "导出命令: hwtest gpio export $GPIO_NUM"
    exit 1
fi

# 设置方向
if ! set_gpio_direction "$GPIO_NUM" "$DIRECTION"; then
    exit 1
fi

# 设置值
if ! set_gpio_value "$GPIO_NUM" "$VALUE"; then
    exit 1
fi

# 验证
if [[ "$VERIFY" == "true" ]]; then
    echo ""
    verify_gpio_value "$GPIO_NUM" "$VALUE"
fi

echo "=========================================="
echo "GPIO设置完成"
