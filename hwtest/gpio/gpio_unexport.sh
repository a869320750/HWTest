#!/bin/bash
# filepath: gpio_unexport.sh
# GPIO取消导出工具

show_usage() {
    echo "用法: hwtest gpio unexport <GPIO编号|GPIO名称|all> [选项]"
    echo ""
    echo "参数:"
    echo "  GPIO编号     : sysfs GPIO编号 (如: 125)"
    echo "  GPIO名称     : Rockchip GPIO名称 (如: GPIO3_D2_D)"
    echo "  all          : 取消导出所有GPIO"
    echo ""
    echo "选项:"
    echo "  -f, --force  强制取消导出(忽略错误)"
    echo "  -v, --verbose 详细输出"
    echo "  --help       显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest gpio unexport 125         # 取消导出GPIO 125"
    echo "  hwtest gpio unexport GPIO3_D2_D  # 取消导出GPIO3_D2_D"
    echo "  hwtest gpio unexport all         # 取消导出所有GPIO"
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
    local force="$2"
    local verbose="$3"
    
    if ! is_gpio_exported "$gpio_num"; then
        if [[ "$verbose" == "true" ]]; then
            echo "GPIO $gpio_num 未导出，无需操作"
        fi
        return 0
    fi
    
    if [[ "$verbose" == "true" ]]; then
        echo "正在取消导出GPIO $gpio_num..."
    fi
    
    if echo "$gpio_num" > /sys/class/gpio/unexport 2>/dev/null; then
        echo "✅ GPIO $gpio_num 已取消导出"
        return 0
    else
        if [[ "$force" == "true" ]]; then
            echo "⚠️  警告: 无法取消导出GPIO $gpio_num (已忽略)"
            return 0
        else
            echo "❌ 错误: 无法取消导出GPIO $gpio_num"
            return 1
        fi
    fi
}

# 获取所有已导出的GPIO
get_exported_gpios() {
    if [[ -d "/sys/class/gpio" ]]; then
        find /sys/class/gpio -maxdepth 1 -name "gpio[0-9]*" -type d | \
        sed 's|.*/gpio||' | sort -n
    fi
}

# 取消导出所有GPIO
unexport_all_gpios() {
    local force="$1"
    local verbose="$2"
    
    local exported_gpios
    exported_gpios=$(get_exported_gpios)
    
    if [[ -z "$exported_gpios" ]]; then
        echo "没有已导出的GPIO"
        return 0
    fi
    
    echo "发现已导出的GPIO: $(echo $exported_gpios | tr '\n' ' ')"
    echo "----------------------------------------"
    
    local success_count=0
    local fail_count=0
    local total_count=0
    
    for gpio_num in $exported_gpios; do
        ((total_count++))
        if unexport_gpio "$gpio_num" "$force" "$verbose"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo "----------------------------------------"
    echo "取消导出完成:"
    echo "  总计: $total_count"
    echo "  成功: $success_count"
    echo "  失败: $fail_count"
    
    return $fail_count
}

# 默认参数
FORCE=false
VERBOSE=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
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
    echo "错误: 请提供GPIO编号、名称或'all'"
    show_usage
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以操作GPIO"
    echo ""
fi

# 处理all参数
if [[ "$GPIO_INPUT" == "all" ]]; then
    echo "=========================================="
    echo "取消导出所有GPIO"
    echo "=========================================="
    unexport_all_gpios "$FORCE" "$VERBOSE"
    exit $?
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
    if [[ "$VERBOSE" == "true" ]]; then
        echo "解析 $GPIO_INPUT -> GPIO编号: $GPIO_NUM"
    fi
fi

echo "=========================================="
echo "取消导出GPIO: $GPIO_NUM"
echo "=========================================="

# 取消导出GPIO
unexport_gpio "$GPIO_NUM" "$FORCE" "$VERBOSE"
