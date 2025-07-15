#!/bin/bash
# filepath: uart_monitor.sh
# 监控串口数据的工具

MONITOR_PID_FILE="/tmp/uart_monitor.pid"

show_usage() {
    echo "用法: hwtest uart monitor [选项] [设备]"
    echo ""
    echo "选项:"
    echo "  -d, --device  <device>    指定串口设备 (如: /dev/ttyS0)"
    echo "  -b, --baud    <rate>      波特率 (默认: 115200)"
    echo "  -t, --timeout <seconds>   超时时间 (默认: 无限制)"
    echo "  -o, --output  <file>      输出到文件"
    echo "  -a, --all                 监控所有可用串口"
    echo "  -s, --stop                停止后台监控"
    echo "  -bg, --background         后台监控模式"
    echo "  --help                    显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest uart monitor -d /dev/ttyS0 -b 9600"
    echo "  hwtest uart monitor -d /dev/ttyS0 --background"
    echo "  hwtest uart monitor --all --background"
    echo "  hwtest uart monitor --stop"
}

stop_monitor() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pids=$(cat "$MONITOR_PID_FILE")
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null
                echo "停止监控进程: $pid"
            fi
        done
        rm -f "$MONITOR_PID_FILE"
        echo "所有监控进程已停止"
    else
        echo "没有运行中的监控进程"
    fi
}

monitor_single_uart() {
    local device=$1
    local baud=$2
    local timeout=$3
    local output_file=$4
    local background=$5
    
    echo "监控串口: $device (波特率: $baud)"
    
    # 检查设备是否存在
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    # 配置串口参数
    stty -F "$device" "$baud" cs8 -cstopb -parity raw -echo || {
        echo "错误: 无法配置串口 $device"
        return 1
    }
    
    # 开始监控
    local monitor_cmd="cat $device"
    
    if [[ -n "$timeout" ]]; then
        monitor_cmd="timeout $timeout $monitor_cmd"
    fi
    
    if [[ "$background" == "true" ]]; then
        # 后台监控模式
        if [[ -n "$output_file" ]]; then
            echo "$(date): 开始后台监控 $device" >> "$output_file"
            $monitor_cmd | while IFS= read -r line; do
                echo "$(date '+%H:%M:%S') [$device]: $line" >> "$output_file"
            done &
        else
            # 后台模式必须有输出文件
            local default_log="/tmp/uart_monitor_${device//\//_}.log"
            echo "后台监控模式，输出到: $default_log"
            echo "$(date): 开始后台监控 $device" > "$default_log"
            $monitor_cmd | while IFS= read -r line; do
                echo "$(date '+%H:%M:%S') [$device]: $line" >> "$default_log"
            done &
        fi
        
        local pid=$!
        echo $pid >> "$MONITOR_PID_FILE"
        echo "后台监控已启动，PID: $pid"
        echo "日志文件: ${output_file:-$default_log}"
        echo "使用 'hwtest uart monitor --stop' 停止监控"
    else
        # 前台监控模式
        echo "按 Ctrl+C 停止监控..."
        if [[ -n "$output_file" ]]; then
            echo "$(date): 开始监控 $device" >> "$output_file"
            $monitor_cmd | while IFS= read -r line; do
                echo "$(date '+%H:%M:%S') [$device]: $line" | tee -a "$output_file"
            done
        else
            $monitor_cmd | while IFS= read -r line; do
                echo "$(date '+%H:%M:%S') [$device]: $line"
            done
        fi
    fi
}

monitor_all_uarts() {
    local baud=$1
    local output_file=$2
    local background=$3
    
    echo "监控所有可用串口..."
    
    # 获取所有串口设备
    local devices=$(ls /dev/ttyS* /dev/ttyUSB* /dev/ttyACM* /dev/ttyAMA* 2>/dev/null)
    
    if [[ -z "$devices" ]]; then
        echo "未找到可用的串口设备"
        return 1
    fi
    
    local pids=()
    
    for device in $devices; do
        if [[ -c "$device" && -r "$device" ]]; then
            echo "启动监控: $device"
            if [[ "$background" == "true" ]]; then
                monitor_single_uart "$device" "$baud" "" "$output_file" "true"
            else
                monitor_single_uart "$device" "$baud" "" "$output_file" "false" &
                local pid=$!
                pids+=($pid)
            fi
        fi
    done
    
    if [[ "$background" != "true" ]]; then
        echo "前台监控进程已启动，PID: ${pids[*]}"
        echo "按 Ctrl+C 停止所有监控"
        
        # 等待用户中断
        trap 'for pid in ${pids[@]}; do kill $pid 2>/dev/null; done; exit 0' INT TERM
        wait
    fi
}

# 默认参数
DEVICE=""
BAUD="115200"
TIMEOUT=""
OUTPUT_FILE=""
MONITOR_ALL=false
BACKGROUND=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -b|--baud)
            BAUD="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -a|--all)
            MONITOR_ALL=true
            shift
            ;;
        -bg|--background)
            BACKGROUND=true
            shift
            ;;
        -s|--stop)
            stop_monitor
            exit 0
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$DEVICE" && -c "$1" ]]; then
                DEVICE="$1"
            else
                echo "未知参数: $1"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以访问串口设备"
    echo ""
fi

# 执行监控
if [[ "$MONITOR_ALL" == "true" ]]; then
    monitor_all_uarts "$BAUD" "$OUTPUT_FILE" "$BACKGROUND"
elif [[ -n "$DEVICE" ]]; then
    monitor_single_uart "$DEVICE" "$BAUD" "$TIMEOUT" "$OUTPUT_FILE" "$BACKGROUND"
else
    echo "请指定要监控的设备或使用 --all 选项"
    show_usage
    exit 1
fi
