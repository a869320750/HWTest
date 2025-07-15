#!/bin/bash
# filepath: gpio_getter.sh
# GPIO读取工具

show_usage() {
    echo "用法: hwtest gpio get <GPIO编号|GPIO名称> [选项]"
    echo ""
    echo "参数:"
    echo "  GPIO编号     : sysfs GPIO编号 (如: 125)"
    echo "  GPIO名称     : Rockchip GPIO名称 (如: GPIO3_D2_D)"
    echo ""
    echo "选项:"
    echo "  -w, --watch <间隔>     持续监控模式，间隔秒数(默认1秒)"
    echo "  -c, --count <次数>     监控次数(默认无限制)"
    echo "  -i, --info             显示详细信息"
    echo "  --help                 显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest gpio get 125                # 读取GPIO 125"
    echo "  hwtest gpio get GPIO3_D2_D         # 读取GPIO3_D2_D"
    echo "  hwtest gpio get 125 --info         # 读取并显示详细信息"
    echo "  hwtest gpio get 125 -w 0.5         # 每0.5秒监控一次"
    echo "  hwtest gpio get 125 -w 1 -c 10     # 监控10次"
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

# 读取GPIO信息
get_gpio_info() {
    local gpio_num="$1"
    local show_info="$2"
    
    if ! is_gpio_exported "$gpio_num"; then
        echo "错误: GPIO $gpio_num 未导出"
        echo "导出命令: hwtest gpio export $gpio_num"
        return 1
    fi
    
    local value direction active_low
    
    # 读取值
    if value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null); then
        local level_name
        case "$value" in
            0) level_name="低电平" ;;
            1) level_name="高电平" ;;
            *) level_name="未知($value)" ;;
        esac
        
        if [[ "$show_info" == "true" ]]; then
            # 读取详细信息
            direction=$(cat "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null || echo "unknown")
            active_low=$(cat "/sys/class/gpio/gpio$gpio_num/active_low" 2>/dev/null || echo "unknown")
            
            echo "=========================================="
            echo "GPIO $gpio_num 详细信息"
            echo "=========================================="
            echo "当前值:     $value ($level_name)"
            echo "方向:       $direction"
            echo "Active Low: $active_low"
            echo "路径:       /sys/class/gpio/gpio$gpio_num"
            echo "=========================================="
        else
            printf "GPIO %d: %s (%s)\n" "$gpio_num" "$value" "$level_name"
        fi
        return 0
    else
        echo "错误: 无法读取GPIO $gpio_num"
        return 1
    fi
}

# 监控GPIO
monitor_gpio() {
    local gpio_num="$1"
    local interval="$2"
    local max_count="$3"
    local show_info="$4"
    
    echo "监控GPIO $gpio_num (间隔: ${interval}s, 按Ctrl+C停止)"
    echo "----------------------------------------"
    
    local count=0
    local last_value=""
    
    while true; do
        if ! is_gpio_exported "$gpio_num"; then
            echo "错误: GPIO $gpio_num 已被取消导出"
            return 1
        fi
        
        local value
        if value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null); then
            local timestamp=$(date '+%H:%M:%S.%3N')
            
            # 检查值是否变化
            local change_indicator=""
            if [[ -n "$last_value" && "$value" != "$last_value" ]]; then
                change_indicator=" ⚡"
            fi
            
            local level_name
            case "$value" in
                0) level_name="低电平" ;;
                1) level_name="高电平" ;;
                *) level_name="未知" ;;
            esac
            
            printf "[%s] GPIO %d: %s (%s)%s\n" "$timestamp" "$gpio_num" "$value" "$level_name" "$change_indicator"
            
            last_value="$value"
            ((count++))
            
            # 检查是否达到最大次数
            if [[ -n "$max_count" && $count -ge $max_count ]]; then
                echo "----------------------------------------"
                echo "监控完成，共 $count 次"
                break
            fi
        else
            echo "错误: 无法读取GPIO $gpio_num"
            return 1
        fi
        
        sleep "$interval"
    done
}

# 默认参数
WATCH_MODE=false
INTERVAL="1"
MAX_COUNT=""
SHOW_INFO=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH_MODE=true
            if [[ -n "$2" && "$2" =~ ^[0-9]*\.?[0-9]+$ ]]; then
                INTERVAL="$2"
                shift 2
            else
                shift
            fi
            ;;
        -c|--count)
            MAX_COUNT="$2"
            shift 2
            ;;
        -i|--info)
            SHOW_INFO=true
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

# 执行读取或监控
if [[ "$WATCH_MODE" == "true" ]]; then
    # 设置中断处理
    trap 'echo ""; echo "监控已停止"; exit 0' INT TERM
    monitor_gpio "$GPIO_NUM" "$INTERVAL" "$MAX_COUNT" "$SHOW_INFO"
else
    get_gpio_info "$GPIO_NUM" "$SHOW_INFO"
fi
