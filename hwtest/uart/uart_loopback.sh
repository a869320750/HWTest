#!/bin/bash
# filepath: uart_loopback.sh
# 串口环回测试工具

show_usage() {
    echo "用法: hwtest uart loopback [选项] <设备>"
    echo ""
    echo "选项:"
    echo "  -d, --device    <device>    指定串口设备 (如: /dev/ttyS0)"
    echo "  -b, --baud      <rate>      波特率 (默认: 115200)"
    echo "  -c, --count     <num>       测试次数 (默认: 10)"
    echo "  -t, --timeout   <seconds>   单次测试超时 (默认: 5)"
    echo "  -s, --size      <bytes>     测试数据大小 (默认: 64)"
    echo "  -v, --verbose               详细输出"
    echo "  --help                      显示帮助"
    echo ""
    echo "说明:"
    echo "  此测试需要将串口的TX和RX引脚短接(硬件环回)"
    echo "  或者在另一端连接相应的环回设备"
    echo ""
    echo "示例:"
    echo "  hwtest uart loopback /dev/ttyS0"
    echo "  hwtest uart loopback -d /dev/ttyS0 -b 9600 -c 20"
}

generate_test_data() {
    local size=$1
    local pattern=""
    
    # 生成测试数据模式
    for ((i=0; i<size; i++)); do
        pattern="${pattern}$(printf '%c' $((65 + (i % 26))))"
    done
    
    echo "$pattern"
}

loopback_test() {
    local device=$1
    local baud=$2
    local count=$3
    local timeout=$4
    local size=$5
    local verbose=$6
    
    echo "=========================================="
    echo "串口环回测试"
    echo "设备: $device"
    echo "波特率: $baud"
    echo "测试次数: $count"
    echo "数据大小: $size 字节"
    echo "超时时间: $timeout 秒"
    echo "=========================================="
    
    # 检查设备是否存在
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    # 配置串口参数
    stty -F "$device" "$baud" cs8 -cstopb -parity raw -echo -crtscts || {
        echo "错误: 无法配置串口 $device"
        return 1
    }
    
    local success_count=0
    local fail_count=0
    local total_time=0
    
    echo ""
    echo "开始测试..."
    
    for ((i=1; i<=count; i++)); do
        local test_data=$(generate_test_data "$size")
        local start_time=$(date +%s.%N)
        
        if [[ "$verbose" == "true" ]]; then
            echo "测试 $i/$count: 发送数据 '$test_data'"
        else
            printf "测试 %d/%d: " "$i" "$count"
        fi
        
        # 清空串口缓冲区
        cat "$device" > /dev/null &
        local cat_pid=$!
        sleep 0.1
        kill $cat_pid 2>/dev/null
        
        # 发送数据
        echo -n "$test_data" > "$device"
        
        # 接收数据
        local received_data=""
        local end_time=$(($(date +%s) + timeout))
        
        while [[ $(date +%s) -lt $end_time ]]; do
            if read -t 1 -r line < "$device"; then
                received_data+="$line"
                if [[ ${#received_data} -ge ${#test_data} ]]; then
                    break
                fi
            fi
        done
        
        local test_time=$(echo "$(date +%s.%N) - $start_time" | bc -l)
        total_time=$(echo "$total_time + $test_time" | bc -l)
        
        # 比较发送和接收的数据
        if [[ "$received_data" == "$test_data"* ]]; then
            ((success_count++))
            if [[ "$verbose" == "true" ]]; then
                printf "成功 ✓ (%.3f秒)\n" "$test_time"
            else
                printf "✓ (%.3fs) " "$test_time"
            fi
        else
            ((fail_count++))
            if [[ "$verbose" == "true" ]]; then
                printf "失败 ✗ (%.3f秒)\n" "$test_time"
                echo "  发送: '$test_data'"
                echo "  接收: '$received_data'"
            else
                printf "✗ (%.3fs) " "$test_time"
            fi
        fi
        
        # 每5个测试结果换行
        if [[ $((i % 5)) -eq 0 && "$verbose" != "true" ]]; then
            echo ""
        fi
        
        sleep 0.1
    done
    
    if [[ "$verbose" != "true" ]]; then
        echo ""
    fi
    
    echo ""
    echo "=========================================="
    echo "测试结果统计:"
    echo "  总测试数: $count"
    echo "  成功: $success_count"
    echo "  失败: $fail_count"
    printf "  成功率: %.1f%%\n" "$(echo "scale=1; $success_count * 100 / $count" | bc -l)"
    printf "  平均耗时: %.3f秒\n" "$(echo "scale=3; $total_time / $count" | bc -l)"
    printf "  总耗时: %.3f秒\n" "$total_time"
    echo "=========================================="
    
    if [[ $fail_count -eq 0 ]]; then
        echo "环回测试通过 ✓"
        return 0
    else
        echo "环回测试失败 ✗"
        return 1
    fi
}

# 默认参数
DEVICE=""
BAUD="115200"
COUNT=10
TIMEOUT=5
SIZE=64
VERBOSE=false

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
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
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

# 检查必要参数
if [[ -z "$DEVICE" ]]; then
    echo "错误: 必须指定串口设备"
    show_usage
    exit 1
fi

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以访问串口设备"
    echo ""
fi

# 检查bc工具
if ! command -v bc >/dev/null 2>&1; then
    echo "错误: 需要安装 bc 工具进行计算"
    echo "请运行: apt-get install bc"
    exit 1
fi

# 执行环回测试
loopback_test "$DEVICE" "$BAUD" "$COUNT" "$TIMEOUT" "$SIZE" "$VERBOSE"
