#!/bin/bash
# filepath: monitor_memory.sh
# 内存监控工具

show_usage() {
    echo "用法: hwtest monitor memory [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --interval <seconds>  监控间隔 (默认: 2秒)"
    echo "  -c, --count <count>       监控次数 (默认: 持续监控)"
    echo "  -t, --threshold <percent> 内存使用率告警阈值 (默认: 85%)"
    echo "  -l, --log <file>          保存日志到文件"
    echo "  -a, --alert               启用告警"
    echo "  -s, --summary             显示统计摘要"
    echo "  -d, --detail              显示详细内存信息"
    echo "  --help                    显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest monitor memory                     # 实时监控"
    echo "  hwtest monitor memory -i 5 -c 10         # 每5秒监控，共10次"
    echo "  hwtest monitor memory -t 90 -a           # 90%告警阈值"
    echo "  hwtest monitor memory -d                  # 显示详细信息"
}

get_memory_info() {
    echo "=========================================="
    echo "内存基本信息"
    echo "=========================================="
    
    # 读取 /proc/meminfo
    local meminfo=$(cat /proc/meminfo)
    
    local total_mem=$(echo "$meminfo" | grep "MemTotal:" | awk '{print $2}')
    local available_mem=$(echo "$meminfo" | grep "MemAvailable:" | awk '{print $2}')
    local free_mem=$(echo "$meminfo" | grep "MemFree:" | awk '{print $2}')
    local buffers=$(echo "$meminfo" | grep "Buffers:" | awk '{print $2}')
    local cached=$(echo "$meminfo" | grep "^Cached:" | awk '{print $2}')
    
    # 转换为MB
    local total_mb=$((total_mem / 1024))
    local available_mb=$((available_mem / 1024))
    local free_mb=$((free_mem / 1024))
    local buffers_mb=$((buffers / 1024))
    local cached_mb=$((cached / 1024))
    
    echo "总内存: ${total_mb}MB"
    echo "可用内存: ${available_mb}MB"
    echo "空闲内存: ${free_mb}MB"
    echo "缓冲区: ${buffers_mb}MB"
    echo "页面缓存: ${cached_mb}MB"
    
    # Swap信息
    local swap_total=$(echo "$meminfo" | grep "SwapTotal:" | awk '{print $2}')
    local swap_free=$(echo "$meminfo" | grep "SwapFree:" | awk '{print $2}')
    
    if [[ $swap_total -gt 0 ]]; then
        local swap_total_mb=$((swap_total / 1024))
        local swap_free_mb=$((swap_free / 1024))
        local swap_used_mb=$((swap_total_mb - swap_free_mb))
        echo "Swap总量: ${swap_total_mb}MB"
        echo "Swap使用: ${swap_used_mb}MB"
    else
        echo "Swap: 未配置"
    fi
    
    echo ""
}

get_memory_usage() {
    # 返回内存使用百分比
    local meminfo=$(cat /proc/meminfo)
    local total_mem=$(echo "$meminfo" | grep "MemTotal:" | awk '{print $2}')
    local available_mem=$(echo "$meminfo" | grep "MemAvailable:" | awk '{print $2}')
    
    if [[ $total_mem -gt 0 ]]; then
        local used_mem=$((total_mem - available_mem))
        local usage_percent=$((100 * used_mem / total_mem))
        echo $usage_percent
    else
        echo 0
    fi
}

get_detailed_memory() {
    echo "详细内存使用情况:"
    
    # 从 /proc/meminfo 获取详细信息
    local meminfo=$(cat /proc/meminfo)
    
    echo "  基本内存:"
    echo "$meminfo" | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached" | \
    while read line; do
        local name=$(echo "$line" | awk '{print $1}' | sed 's/://')
        local value=$(echo "$line" | awk '{print $2}')
        local value_mb=$((value / 1024))
        printf "    %-12s: %8s MB\n" "$name" "$value_mb"
    done
    
    echo ""
    echo "  Swap信息:"
    echo "$meminfo" | grep -E "SwapTotal|SwapFree|SwapCached" | \
    while read line; do
        local name=$(echo "$line" | awk '{print $1}' | sed 's/://')
        local value=$(echo "$line" | awk '{print $2}')
        local value_mb=$((value / 1024))
        printf "    %-12s: %8s MB\n" "$name" "$value_mb"
    done
    
    echo ""
    echo "  内核内存:"
    echo "$meminfo" | grep -E "Slab|SReclaimable|SUnreclaim|KernelStack|PageTables" | \
    while read line; do
        local name=$(echo "$line" | awk '{print $1}' | sed 's/://')
        local value=$(echo "$line" | awk '{print $2}')
        local value_mb=$((value / 1024))
        printf "    %-12s: %8s MB\n" "$name" "$value_mb"
    done
}

get_top_memory_processes() {
    echo "内存占用最高的进程:"
    ps aux --sort=-%mem | head -6 | awk 'NR==1{print "  " $0} NR>1{printf "  %-8s %5s%% %s\n", $2, $4, $11}' 2>/dev/null
}

get_memory_distribution() {
    local meminfo=$(cat /proc/meminfo)
    local total_mem=$(echo "$meminfo" | grep "MemTotal:" | awk '{print $2}')
    local free_mem=$(echo "$meminfo" | grep "MemFree:" | awk '{print $2}')
    local buffers=$(echo "$meminfo" | grep "Buffers:" | awk '{print $2}')
    local cached=$(echo "$meminfo" | grep "^Cached:" | awk '{print $2}')
    local slab=$(echo "$meminfo" | grep "Slab:" | awk '{print $2}')
    
    # 计算各部分占比
    local used_mem=$((total_mem - free_mem - buffers - cached))
    
    echo "内存分布:"
    printf "  应用程序: %d MB (%d%%)\n" $((used_mem / 1024)) $((100 * used_mem / total_mem))
    printf "  缓冲区:   %d MB (%d%%)\n" $((buffers / 1024)) $((100 * buffers / total_mem))
    printf "  页面缓存: %d MB (%d%%)\n" $((cached / 1024)) $((100 * cached / total_mem))
    printf "  内核:     %d MB (%d%%)\n" $((slab / 1024)) $((100 * slab / total_mem))
    printf "  空闲:     %d MB (%d%%)\n" $((free_mem / 1024)) $((100 * free_mem / total_mem))
}

monitor_memory() {
    local interval=$1
    local count=$2
    local threshold=$3
    local log_file=$4
    local enable_alert=$5
    local show_summary=$6
    local show_detail=$7
    
    get_memory_info
    
    local total_usage=0
    local max_usage=0
    local min_usage=100
    local alert_count=0
    local loop_count=0
    
    echo "开始内存监控 (间隔: ${interval}秒, 告警阈值: ${threshold}%)"
    echo "按 Ctrl+C 停止监控"
    echo ""
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local mem_usage=$(get_memory_usage)
        
        # 更新统计
        total_usage=$((total_usage + mem_usage))
        loop_count=$((loop_count + 1))
        
        if [[ $mem_usage -gt $max_usage ]]; then
            max_usage=$mem_usage
        fi
        
        if [[ $mem_usage -lt $min_usage ]]; then
            min_usage=$mem_usage
        fi
        
        # 显示监控信息
        local status="正常"
        local alert_mark=""
        
        if [[ $mem_usage -ge $threshold ]]; then
            status="告警"
            alert_mark="⚠️ "
            alert_count=$((alert_count + 1))
            
            if [[ "$enable_alert" == "true" ]]; then
                echo "🚨 内存使用率告警: ${mem_usage}% (阈值: ${threshold}%)"
            fi
        fi
        
        printf "%s${alert_mark}内存使用率: %3d%% (%s)\n" "$timestamp" "$mem_usage" "$status"
        
        # 显示内存分布
        get_memory_distribution
        echo ""
        
        # 显示详细信息
        if [[ "$show_detail" == "true" ]]; then
            get_detailed_memory
            echo ""
        fi
        
        # 显示进程信息
        get_top_memory_processes
        echo "----------------------------------------"
        
        # 记录日志
        if [[ -n "$log_file" ]]; then
            echo "$timestamp,Memory,$mem_usage,$status" >> "$log_file"
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
THRESHOLD=85
LOG_FILE=""
ENABLE_ALERT=false
SHOW_SUMMARY=true
SHOW_DETAIL=false

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
        -d|--detail)
            SHOW_DETAIL=true
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
monitor_memory "$INTERVAL" "$COUNT" "$THRESHOLD" "$LOG_FILE" "$ENABLE_ALERT" "$SHOW_SUMMARY" "$SHOW_DETAIL"
