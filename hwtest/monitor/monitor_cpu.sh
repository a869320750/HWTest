#!/bin/bash
# filepath: monitor_cpu.sh
# CPU监控工具

show_usage() {
    echo "用法: hwtest monitor cpu [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --interval <seconds>  监控间隔 (默认: 2秒)"
    echo "  -c, --count <count>       监控次数 (默认: 持续监控)"
    echo "  -t, --threshold <percent> CPU使用率告警阈值 (默认: 80%)"
    echo "  -l, --log <file>          保存日志到文件"
    echo "  -a, --alert               启用告警"
    echo "  -s, --summary             显示统计摘要"
    echo "  --help                    显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest monitor cpu                    # 实时监控"
    echo "  hwtest monitor cpu -i 5 -c 10        # 每5秒监控，共10次"
    echo "  hwtest monitor cpu -t 90 -a          # 90%告警阈值"
    echo "  hwtest monitor cpu -l /tmp/cpu.log   # 记录日志"
}

get_cpu_info() {
    echo "=========================================="
    echo "CPU基本信息"
    echo "=========================================="
    
    # CPU型号
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
    echo "CPU型号: $cpu_model"
    
    # CPU核心数
    local cpu_cores=$(nproc)
    echo "CPU核心数: $cpu_cores"
    
    # CPU频率
    if [[ -r "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        if [[ -n "$freq" ]]; then
            local freq_mhz=$((freq / 1000))
            echo "当前频率: ${freq_mhz}MHz"
        fi
    fi
    
    # CPU温度 (如果可用)
    if [[ -r "/sys/class/thermal/thermal_zone0/temp" ]]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [[ -n "$temp" ]]; then
            local temp_c=$((temp / 1000))
            echo "CPU温度: ${temp_c}°C"
        fi
    fi
    
    echo ""
}

get_cpu_usage() {
    # 读取两次 /proc/stat 计算CPU使用率
    local stat1=$(grep '^cpu ' /proc/stat)
    sleep 1
    local stat2=$(grep '^cpu ' /proc/stat)
    
    # 解析数据
    local prev_idle=$(echo $stat1 | awk '{print $5}')
    local prev_total=$(echo $stat1 | awk '{sum=0; for(i=2; i<=NF; i++) sum+=$i; print sum}')
    
    local idle=$(echo $stat2 | awk '{print $5}')
    local total=$(echo $stat2 | awk '{sum=0; for(i=2; i<=NF; i++) sum+=$i; print sum}')
    
    # 计算使用率
    local idle_delta=$((idle - prev_idle))
    local total_delta=$((total - prev_total))
    
    if [[ $total_delta -gt 0 ]]; then
        local usage=$((100 * (total_delta - idle_delta) / total_delta))
        echo $usage
    else
        echo 0
    fi
}

get_per_core_usage() {
    # 获取每个核心的使用率
    local cores=$(nproc)
    
    # 读取两次数据
    local stat1=$(grep '^cpu[0-9]' /proc/stat)
    sleep 1
    local stat2=$(grep '^cpu[0-9]' /proc/stat)
    
    echo "各核心使用率:"
    for ((i=0; i<cores; i++)); do
        local prev_data=$(echo "$stat1" | grep "^cpu$i " | awk '{print $5, $2+$3+$4+$5+$6+$7+$8}')
        local curr_data=$(echo "$stat2" | grep "^cpu$i " | awk '{print $5, $2+$3+$4+$5+$6+$7+$8}')
        
        if [[ -n "$prev_data" && -n "$curr_data" ]]; then
            local prev_idle=$(echo $prev_data | awk '{print $1}')
            local prev_total=$(echo $prev_data | awk '{print $2}')
            local curr_idle=$(echo $curr_data | awk '{print $1}')
            local curr_total=$(echo $curr_data | awk '{print $2}')
            
            local idle_delta=$((curr_idle - prev_idle))
            local total_delta=$((curr_total - prev_total))
            
            if [[ $total_delta -gt 0 ]]; then
                local usage=$((100 * (total_delta - idle_delta) / total_delta))
                printf "  CPU%d: %3d%%\n" $i $usage
            fi
        fi
    done
}

get_load_average() {
    local loadavg=$(cat /proc/loadavg)
    echo "负载平均值: $loadavg"
}

get_top_processes() {
    echo "CPU占用最高的进程:"
    ps aux --sort=-%cpu | head -6 | awk 'NR==1{print "  " $0} NR>1{printf "  %-8s %5s%% %s\n", $2, $3, $11}' 2>/dev/null
}

monitor_cpu() {
    local interval=$1
    local count=$2
    local threshold=$3
    local log_file=$4
    local enable_alert=$5
    local show_summary=$6
    
    get_cpu_info
    
    local total_usage=0
    local max_usage=0
    local min_usage=100
    local alert_count=0
    local loop_count=0
    
    echo "开始CPU监控 (间隔: ${interval}秒, 告警阈值: ${threshold}%)"
    echo "按 Ctrl+C 停止监控"
    echo ""
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local cpu_usage=$(get_cpu_usage)
        
        # 更新统计
        total_usage=$((total_usage + cpu_usage))
        loop_count=$((loop_count + 1))
        
        if [[ $cpu_usage -gt $max_usage ]]; then
            max_usage=$cpu_usage
        fi
        
        if [[ $cpu_usage -lt $min_usage ]]; then
            min_usage=$cpu_usage
        fi
        
        # 显示监控信息
        local status="正常"
        local alert_mark=""
        
        if [[ $cpu_usage -ge $threshold ]]; then
            status="告警"
            alert_mark="⚠️ "
            alert_count=$((alert_count + 1))
            
            if [[ "$enable_alert" == "true" ]]; then
                echo "🚨 CPU使用率告警: ${cpu_usage}% (阈值: ${threshold}%)"
            fi
        fi
        
        printf "%s${alert_mark}CPU使用率: %3d%% (%s)\n" "$timestamp" "$cpu_usage" "$status"
        
        # 显示负载和进程信息
        get_load_average
        echo ""
        get_per_core_usage
        echo ""
        get_top_processes
        echo "----------------------------------------"
        
        # 记录日志
        if [[ -n "$log_file" ]]; then
            echo "$timestamp,CPU,$cpu_usage,$status" >> "$log_file"
        fi
        
        # 检查是否达到次数限制
        if [[ $count -gt 0 && $loop_count -ge $count ]]; then
            break
        fi
        
        sleep "$interval"
    done
    
    # 显示统计摘要
    if [[ "$show_summary" == "true" && $loop_count -gt 0 ]]; then
        echo ""
        echo "=========================================="
        echo "监控统计摘要:"
        echo "  监控时长: $((loop_count * interval)) 秒"
        echo "  监控次数: $loop_count"
        echo "  平均使用率: $((total_usage / loop_count))%"
        echo "  最大使用率: ${max_usage}%"
        echo "  最小使用率: ${min_usage}%"
        echo "  告警次数: $alert_count"
        if [[ -n "$log_file" ]]; then
            echo "  日志文件: $log_file"
        fi
        echo "=========================================="
    fi
}

# 默认参数
INTERVAL=2
COUNT=0
THRESHOLD=80
LOG_FILE=""
ENABLE_ALERT=false
SHOW_SUMMARY=true

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
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
            ENABLE_ALERT=true
            shift
            ;;
        -s|--summary)
            SHOW_SUMMARY=true
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

# 设置信号处理
trap 'echo -e "\n监控已停止"; exit 0' INT TERM

# 执行监控
monitor_cpu "$INTERVAL" "$COUNT" "$THRESHOLD" "$LOG_FILE" "$ENABLE_ALERT" "$SHOW_SUMMARY"
