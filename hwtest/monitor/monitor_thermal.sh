#!/bin/bash
# filepath: monitor_thermal.sh
# 系统温度监控工具

show_usage() {
    echo "用法: hwtest monitor thermal [选项]"
    echo ""
    echo "选项:"
    echo "  -w, --watch <间隔>     持续监控模式，间隔秒数(默认2秒)"
    echo "  -c, --count <次数>     监控次数(默认无限制)"
    echo "  -t, --threshold <温度> 设置告警温度阈值(℃)"
    echo "  -l, --log <文件>       将结果记录到文件"
    echo "  -a, --alert            启用温度告警"
    echo "  --help                 显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest monitor thermal              # 显示当前温度"
    echo "  hwtest monitor thermal -w 1        # 每秒监控"
    echo "  hwtest monitor thermal -t 80 -a    # 80℃告警"
}

# 获取所有温度传感器
get_thermal_zones() {
    find /sys/class/thermal -name "thermal_zone*" 2>/dev/null | sort
}

# 读取温度传感器信息
read_thermal_info() {
    local zone_path="$1"
    local zone_name=$(basename "$zone_path")
    local temp_file="$zone_path/temp"
    local type_file="$zone_path/type"
    
    if [[ -f "$temp_file" && -f "$type_file" ]]; then
        local temp_raw=$(cat "$temp_file" 2>/dev/null)
        local temp_type=$(cat "$type_file" 2>/dev/null)
        
        if [[ -n "$temp_raw" && "$temp_raw" =~ ^[0-9]+$ ]]; then
            # 温度值通常是毫摄氏度，转换为摄氏度
            local temp_celsius=$((temp_raw / 1000))
            echo "$zone_name:$temp_type:$temp_celsius"
            return 0
        fi
    fi
    return 1
}

# 显示温度信息
show_thermal_status() {
    local threshold="$1"
    local show_alert="$2"
    local log_file="$3"
    
    local zones=$(get_thermal_zones)
    if [[ -z "$zones" ]]; then
        echo "未找到温度传感器"
        return 1
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local max_temp=0
    local alert_zones=""
    
    printf "\n========================================\n"
    printf "系统温度监控 - %s\n" "$timestamp"
    printf "========================================\n"
    printf "%-15s %-20s %s\n" "传感器" "类型" "温度(℃)"
    printf "----------------------------------------\n"
    
    for zone in $zones; do
        local info=$(read_thermal_info "$zone")
        if [[ -n "$info" ]]; then
            IFS=':' read -r zone_name temp_type temp_value <<< "$info"
            
            # 温度状态指示
            local status_icon="🟢"
            local status_text=""
            
            if [[ -n "$threshold" && $temp_value -gt $threshold ]]; then
                status_icon="🔴"
                status_text=" ⚠️ HIGH"
                alert_zones+="$temp_type($temp_value°C) "
            elif [[ $temp_value -gt 70 ]]; then
                status_icon="🟡"
                status_text=" ⚠️ WARM"
            fi
            
            printf "%s %-15s %-20s %d°C%s\n" "$status_icon" "$zone_name" "$temp_type" "$temp_value" "$status_text"
            
            # 记录最高温度
            if [[ $temp_value -gt $max_temp ]]; then
                max_temp=$temp_value
            fi
            
            # 记录到日志文件
            if [[ -n "$log_file" ]]; then
                echo "$timestamp,$zone_name,$temp_type,$temp_value" >> "$log_file"
            fi
        fi
    done
    
    printf "----------------------------------------\n"
    printf "最高温度: %d°C\n" "$max_temp"
    
    # 告警处理
    if [[ "$show_alert" == "true" && -n "$alert_zones" ]]; then
        printf "\n🚨 温度告警: %s\n" "$alert_zones"
        # 可以在这里添加告警通知，如发送邮件、写入系统日志等
        logger "HWTest温度告警: $alert_zones"
    fi
    
    printf "========================================\n"
}

# 监控模式
monitor_thermal() {
    local interval="$1"
    local max_count="$2"
    local threshold="$3"
    local show_alert="$4"
    local log_file="$5"
    
    echo "温度监控模式 (间隔: ${interval}s, 按Ctrl+C停止)"
    
    # 设置中断处理
    trap 'echo ""; echo "监控已停止"; exit 0' INT TERM
    
    local count=0
    
    while true; do
        clear  # 清屏以获得更好的显示效果
        show_thermal_status "$threshold" "$show_alert" "$log_file"
        
        ((count++))
        
        # 检查是否达到最大次数
        if [[ -n "$max_count" && $count -ge $max_count ]]; then
            echo "监控完成，共 $count 次"
            break
        fi
        
        sleep "$interval"
    done
}

# 默认参数
WATCH_MODE=false
INTERVAL="2"
MAX_COUNT=""
THRESHOLD=""
SHOW_ALERT=false
LOG_FILE=""

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
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -a|--alert)
            SHOW_ALERT=true
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

# 创建日志文件头部
if [[ -n "$LOG_FILE" ]]; then
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "timestamp,zone,type,temperature" > "$LOG_FILE"
        echo "温度日志将保存到: $LOG_FILE"
    fi
fi

# 执行监控
if [[ "$WATCH_MODE" == "true" ]]; then
    monitor_thermal "$INTERVAL" "$MAX_COUNT" "$THRESHOLD" "$SHOW_ALERT" "$LOG_FILE"
else
    show_thermal_status "$THRESHOLD" "$SHOW_ALERT" "$LOG_FILE"
fi
