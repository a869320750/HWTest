#!/bin/bash
# filepath: gpio_scanner.sh
# GPIO扫描工具

show_usage() {
    echo "用法: hwtest gpio scan [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all        显示所有GPIO信息(包括未导出的)"
    echo "  -s, --summary    显示摘要信息"
    echo "  -w, --watch      监控模式，实时显示变化"
    echo "  --help           显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest gpio scan              # 扫描已导出的GPIO"
    echo "  hwtest gpio scan --all        # 显示所有GPIO状态"
    echo "  hwtest gpio scan --summary    # 显示摘要"
    echo "  hwtest gpio scan --watch      # 监控模式"
}

# 获取所有已导出的GPIO
get_exported_gpios() {
    if [[ -d "/sys/class/gpio" ]]; then
        find /sys/class/gpio -maxdepth 1 -name "gpio[0-9]*" -type d | \
        sed 's|.*/gpio||' | sort -n
    fi
}

# 获取GPIO详细信息
get_gpio_detail() {
    local gpio_num="$1"
    local show_path="$2"
    
    if [[ ! -d "/sys/class/gpio/gpio$gpio_num" ]]; then
        echo "GPIO $gpio_num: 未导出"
        return 1
    fi
    
    local value direction active_low edge
    value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null || echo "unknown")
    direction=$(cat "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null || echo "unknown")
    active_low=$(cat "/sys/class/gpio/gpio$gpio_num/active_low" 2>/dev/null || echo "unknown")
    
    # 检查是否支持edge
    if [[ -f "/sys/class/gpio/gpio$gpio_num/edge" ]]; then
        edge=$(cat "/sys/class/gpio/gpio$gpio_num/edge" 2>/dev/null || echo "unknown")
    else
        edge="不支持"
    fi
    
    local level_name
    case "$value" in
        0) level_name="低电平" ;;
        1) level_name="高电平" ;;
        *) level_name="未知" ;;
    esac
    
    printf "GPIO %-3d: %s %-8s | 方向: %-3s | Active Low: %s" \
           "$gpio_num" "$value" "($level_name)" "$direction" "$active_low"
    
    if [[ "$edge" != "不支持" ]]; then
        printf " | Edge: %s" "$edge"
    fi
    
    if [[ "$show_path" == "true" ]]; then
        printf " | 路径: /sys/class/gpio/gpio%d" "$gpio_num"
    fi
    
    printf "\n"
}

# 扫描已导出GPIO
scan_exported_gpios() {
    local show_path="$1"
    
    local exported_gpios
    exported_gpios=$(get_exported_gpios)
    
    if [[ -z "$exported_gpios" ]]; then
        echo "没有发现已导出的GPIO"
        return 0
    fi
    
    echo "=========================================="
    echo "已导出的GPIO列表"
    echo "=========================================="
    echo "编号     值    电平      | 方向  | Active Low | Edge"
    echo "----------------------------------------"
    
    for gpio_num in $exported_gpios; do
        get_gpio_detail "$gpio_num" "$show_path"
    done
    
    local count=$(echo "$exported_gpios" | wc -w)
    echo "----------------------------------------"
    echo "总计: $count 个已导出的GPIO"
}

# 显示系统GPIO摘要
show_gpio_summary() {
    echo "=========================================="
    echo "GPIO系统摘要"
    echo "=========================================="
    
    # 检查GPIO控制器
    echo "1. GPIO控制器:"
    echo "----------------------------------------"
    if [[ -d "/sys/class/gpio" ]]; then
        echo "SysFS GPIO接口: 可用 ✓"
        
        # 检查gpiochip
        local gpiochips
        gpiochips=$(find /sys/class/gpio -name "gpiochip*" 2>/dev/null | sort)
        if [[ -n "$gpiochips" ]]; then
            for chip in $gpiochips; do
                local base label ngpio
                base=$(cat "$chip/base" 2>/dev/null || echo "unknown")
                label=$(cat "$chip/label" 2>/dev/null || echo "unknown")
                ngpio=$(cat "$chip/ngpio" 2>/dev/null || echo "unknown")
                printf "  %-15s: base=%s, ngpio=%s, label=%s\n" \
                       "$(basename $chip)" "$base" "$ngpio" "$label"
            done
        else
            echo "  未发现GPIO芯片"
        fi
    else
        echo "SysFS GPIO接口: 不可用 ✗"
    fi
    
    echo ""
    echo "2. 已导出GPIO统计:"
    echo "----------------------------------------"
    local exported_gpios
    exported_gpios=$(get_exported_gpios)
    
    if [[ -n "$exported_gpios" ]]; then
        local total_count input_count output_count high_count low_count
        total_count=$(echo "$exported_gpios" | wc -w)
        input_count=0
        output_count=0
        high_count=0
        low_count=0
        
        for gpio_num in $exported_gpios; do
            local direction value
            direction=$(cat "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null)
            value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null)
            
            case "$direction" in
                "in") ((input_count++)) ;;
                "out") ((output_count++)) ;;
            esac
            
            case "$value" in
                "0") ((low_count++)) ;;
                "1") ((high_count++)) ;;
            esac
        done
        
        echo "  总计: $total_count"
        echo "  输入: $input_count"
        echo "  输出: $output_count"
        echo "  高电平: $high_count"
        echo "  低电平: $low_count"
        
        echo ""
        echo "  GPIO编号列表: $(echo $exported_gpios | tr '\n' ' ')"
    else
        echo "  无已导出的GPIO"
    fi
    
    echo ""
    echo "3. 内核GPIO驱动:"
    echo "----------------------------------------"
    local gpio_drivers
    gpio_drivers=$(lsmod 2>/dev/null | grep -i gpio)
    if [[ -n "$gpio_drivers" ]]; then
        echo "$gpio_drivers"
    else
        echo "  未找到GPIO相关模块"
    fi
}

# 监控GPIO变化
monitor_gpios() {
    echo "GPIO监控模式 (按Ctrl+C停止)"
    echo "=========================================="
    
    # 设置中断处理
    trap 'echo ""; echo "监控已停止"; exit 0' INT TERM
    
    local last_state=""
    
    while true; do
        local exported_gpios
        exported_gpios=$(get_exported_gpios)
        
        if [[ -n "$exported_gpios" ]]; then
            local current_state=""
            
            for gpio_num in $exported_gpios; do
                local value direction
                value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null || echo "?")
                direction=$(cat "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null || echo "?")
                current_state+="$gpio_num:$direction:$value "
            done
            
            # 检查状态是否变化
            if [[ "$current_state" != "$last_state" ]]; then
                local timestamp=$(date '+%H:%M:%S')
                echo "[$timestamp] GPIO状态变化:"
                echo "编号     值    方向"
                echo "----------------"
                
                for gpio_num in $exported_gpios; do
                    local value direction
                    value=$(cat "/sys/class/gpio/gpio$gpio_num/value" 2>/dev/null || echo "?")
                    direction=$(cat "/sys/class/gpio/gpio$gpio_num/direction" 2>/dev/null || echo "?")
                    
                    local level_name
                    case "$value" in
                        0) level_name="低电平" ;;
                        1) level_name="高电平" ;;
                        *) level_name="未知" ;;
                    esac
                    
                    printf "GPIO %-3d: %s %-8s %s\n" "$gpio_num" "$value" "($level_name)" "$direction"
                done
                echo "----------------------------------------"
                
                last_state="$current_state"
            fi
        else
            if [[ -n "$last_state" ]]; then
                echo "[$(date '+%H:%M:%S')] 所有GPIO已取消导出"
                last_state=""
            fi
        fi
        
        sleep 1
    done
}

# 默认参数
SHOW_ALL=false
SHOW_SUMMARY=false
WATCH_MODE=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -s|--summary)
            SHOW_SUMMARY=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以获得完整信息"
    echo ""
fi

# 执行扫描
if [[ "$WATCH_MODE" == "true" ]]; then
    monitor_gpios
elif [[ "$SHOW_SUMMARY" == "true" ]]; then
    show_gpio_summary
else
    scan_exported_gpios "$SHOW_ALL"
fi
