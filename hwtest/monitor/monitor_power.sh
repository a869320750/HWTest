#!/bin/bash
# filepath: monitor_power.sh
# 功耗监控工具

show_usage() {
    echo "用法: hwtest monitor power [选项]"
    echo ""
    echo "选项:"
    echo "  -i, --interval <seconds>  监控间隔 (默认: 5秒)"
    echo "  -c, --count <count>       监控次数 (默认: 持续监控)"
    echo "  -l, --log <file>          保存日志到文件"
    echo "  -s, --summary             显示统计摘要"
    echo "  -d, --detail              显示详细功耗信息"
    echo "  --help                    显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest monitor power                    # 实时监控"
    echo "  hwtest monitor power -i 10 -c 20       # 每10秒监控，共20次"
    echo "  hwtest monitor power -d                 # 显示详细信息"
    echo "  hwtest monitor power -l /tmp/power.log # 记录日志"
}

get_power_info() {
    echo "=========================================="
    echo "电源和功耗信息"
    echo "=========================================="
    
    # 检查电源供应信息
    if [[ -d "/sys/class/power_supply" ]]; then
        echo "电源供应设备:"
        for psu in /sys/class/power_supply/*; do
            if [[ -d "$psu" ]]; then
                local psu_name=$(basename "$psu")
                local psu_type=""
                local psu_status=""
                local psu_capacity=""
                local psu_voltage=""
                local psu_current=""
                
                if [[ -r "$psu/type" ]]; then
                    psu_type=$(cat "$psu/type" 2>/dev/null)
                fi
                
                if [[ -r "$psu/status" ]]; then
                    psu_status=$(cat "$psu/status" 2>/dev/null)
                fi
                
                if [[ -r "$psu/capacity" ]]; then
                    psu_capacity=$(cat "$psu/capacity" 2>/dev/null)
                fi
                
                if [[ -r "$psu/voltage_now" ]]; then
                    local voltage_uv=$(cat "$psu/voltage_now" 2>/dev/null)
                    if [[ -n "$voltage_uv" ]]; then
                        psu_voltage=$((voltage_uv / 1000))  # 转换为mV
                    fi
                fi
                
                if [[ -r "$psu/current_now" ]]; then
                    local current_ua=$(cat "$psu/current_now" 2>/dev/null)
                    if [[ -n "$current_ua" ]]; then
                        psu_current=$((current_ua / 1000))  # 转换为mA
                    fi
                fi
                
                echo "  $psu_name ($psu_type):"
                [[ -n "$psu_status" ]] && echo "    状态: $psu_status"
                [[ -n "$psu_capacity" ]] && echo "    电量: ${psu_capacity}%"
                [[ -n "$psu_voltage" ]] && echo "    电压: ${psu_voltage}mV"
                [[ -n "$psu_current" ]] && echo "    电流: ${psu_current}mA"
            fi
        done
    else
        echo "未找到电源供应信息"
    fi
    
    echo ""
}

get_thermal_info() {
    echo "温度信息:"
    
    # 检查thermal zones
    local thermal_found=false
    if [[ -d "/sys/class/thermal" ]]; then
        for thermal in /sys/class/thermal/thermal_zone*; do
            if [[ -d "$thermal" ]]; then
                thermal_found=true
                local zone_name=$(basename "$thermal")
                local zone_type=""
                local zone_temp=""
                
                if [[ -r "$thermal/type" ]]; then
                    zone_type=$(cat "$thermal/type" 2>/dev/null)
                fi
                
                if [[ -r "$thermal/temp" ]]; then
                    local temp_millic=$(cat "$thermal/temp" 2>/dev/null)
                    if [[ -n "$temp_millic" ]]; then
                        zone_temp=$((temp_millic / 1000))
                    fi
                fi
                
                printf "  %-15s: %s°C (%s)\n" "$zone_name" "$zone_temp" "$zone_type"
            fi
        done
    fi
    
    if [[ "$thermal_found" == "false" ]]; then
        echo "  未找到温度传感器"
    fi
    
    echo ""
}

get_cpu_frequency() {
    echo "CPU频率信息:"
    
    local cpu_count=$(nproc)
    for ((i=0; i<cpu_count; i++)); do
        local freq_path="/sys/devices/system/cpu/cpu$i/cpufreq"
        if [[ -d "$freq_path" ]]; then
            local cur_freq=""
            local min_freq=""
            local max_freq=""
            local governor=""
            
            if [[ -r "$freq_path/scaling_cur_freq" ]]; then
                local freq_khz=$(cat "$freq_path/scaling_cur_freq" 2>/dev/null)
                if [[ -n "$freq_khz" ]]; then
                    cur_freq=$((freq_khz / 1000))
                fi
            fi
            
            if [[ -r "$freq_path/scaling_min_freq" ]]; then
                local freq_khz=$(cat "$freq_path/scaling_min_freq" 2>/dev/null)
                if [[ -n "$freq_khz" ]]; then
                    min_freq=$((freq_khz / 1000))
                fi
            fi
            
            if [[ -r "$freq_path/scaling_max_freq" ]]; then
                local freq_khz=$(cat "$freq_path/scaling_max_freq" 2>/dev/null)
                if [[ -n "$freq_khz" ]]; then
                    max_freq=$((freq_khz / 1000))
                fi
            fi
            
            if [[ -r "$freq_path/scaling_governor" ]]; then
                governor=$(cat "$freq_path/scaling_governor" 2>/dev/null)
            fi
            
            printf "  CPU%d: %4dMHz (范围: %d-%dMHz, 调频器: %s)\n" \
                   "$i" "$cur_freq" "$min_freq" "$max_freq" "$governor"
        fi
    done
    
    echo ""
}

calculate_power_consumption() {
    # 尝试计算功耗 (如果有电压和电流信息)
    local total_power=0
    local power_sources=0
    
    for psu in /sys/class/power_supply/*; do
        if [[ -d "$psu" ]]; then
            local voltage_file="$psu/voltage_now"
            local current_file="$psu/current_now"
            local power_file="$psu/power_now"
            
            # 优先使用直接的功耗读数
            if [[ -r "$power_file" ]]; then
                local power_uw=$(cat "$power_file" 2>/dev/null)
                if [[ -n "$power_uw" && $power_uw -gt 0 ]]; then
                    local power_mw=$((power_uw / 1000))
                    total_power=$((total_power + power_mw))
                    power_sources=$((power_sources + 1))
                fi
            # 否则通过电压和电流计算
            elif [[ -r "$voltage_file" && -r "$current_file" ]]; then
                local voltage_uv=$(cat "$voltage_file" 2>/dev/null)
                local current_ua=$(cat "$current_file" 2>/dev/null)
                
                if [[ -n "$voltage_uv" && -n "$current_ua" && $voltage_uv -gt 0 && $current_ua -gt 0 ]]; then
                    # P = V * I (功率 = 电压 * 电流)
                    local power_mw=$((voltage_uv * current_ua / 1000000))
                    total_power=$((total_power + power_mw))
                    power_sources=$((power_sources + 1))
                fi
            fi
        fi
    done
    
    if [[ $power_sources -gt 0 ]]; then
        local power_w=$((total_power / 1000))
        echo "估算功耗: ${power_w}.$(printf "%03d" $((total_power % 1000)))W"
    else
        echo "估算功耗: 无法计算 (缺少电压/电流数据)"
    fi
}

get_power_status() {
    echo "功耗状态:"
    
    # 计算功耗
    calculate_power_consumption
    
    # 显示CPU使用率 (影响功耗)
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null)
    if [[ -n "$cpu_usage" ]]; then
        echo "CPU使用率: ${cpu_usage}%"
    fi
    
    # 显示负载
    local loadavg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo "系统负载: $loadavg"
    
    echo ""
}

monitor_power() {
    local interval=$1
    local count=$2
    local log_file=$3
    local show_summary=$4
    local show_detail=$5
    
    get_power_info
    
    local loop_count=0
    
    echo "开始功耗监控 (间隔: ${interval}秒)"
    echo "按 Ctrl+C 停止监控"
    echo ""
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo "[$timestamp]"
        echo "----------------------------------------"
        
        # 显示功耗状态
        get_power_status
        
        # 显示温度信息
        get_thermal_info
        
        # 显示详细信息
        if [[ "$show_detail" == "true" ]]; then
            get_cpu_frequency
        fi
        
        loop_count=$((loop_count + 1))
        
        # 记录日志
        if [[ -n "$log_file" ]]; then
            echo "$timestamp,Power,Monitor,Normal" >> "$log_file"
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
        if [[ -n "$log_file" ]]; then
            echo "  日志文件: $log_file"
        fi
        echo "=========================================="
    fi
}

# 默认参数
INTERVAL=5
COUNT=0
LOG_FILE=""
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
        -l|--log)
            LOG_FILE="$2"
            shift 2
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
monitor_power "$INTERVAL" "$COUNT" "$LOG_FILE" "$SHOW_SUMMARY" "$SHOW_DETAIL"
