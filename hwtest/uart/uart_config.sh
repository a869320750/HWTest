#!/bin/bash
# filepath: uart_config.sh
# 串口参数配置工具

show_usage() {
    echo "用法: hwtest uart config [选项] <设备>"
    echo ""
    echo "选项:"
    echo "  -d, --device    <device>    指定串口设备 (如: /dev/ttyS0)"
    echo "  -b, --baud      <rate>      设置波特率"
    echo "  -s, --show                  显示当前配置"
    echo "  -r, --reset                 重置为默认配置"
    echo "  --databits      <5|6|7|8>   数据位"
    echo "  --stopbits      <1|2>       停止位"
    echo "  --parity        <none|odd|even>  校验位"
    echo "  --flow          <none|rtscts|xonxoff>  流控制"
    echo "  --help                      显示帮助"
    echo ""
    echo "常用波特率: 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600"
    echo ""
    echo "示例:"
    echo "  hwtest uart config /dev/ttyS0 --show"
    echo "  hwtest uart config -d /dev/ttyS0 -b 9600"
    echo "  hwtest uart config -d /dev/ttyS0 -b 115200 --databits 8 --parity none"
}

show_config() {
    local device=$1
    
    echo "=========================================="
    echo "串口配置信息: $device"
    echo "=========================================="
    
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    # 显示当前配置
    echo "当前配置:"
    stty -F "$device" -a | sed 's/;/\n/g' | while read line; do
        if [[ -n "$line" ]]; then
            echo "  $line"
        fi
    done
    
    echo ""
    echo "详细参数:"
    
    # 获取波特率
    local baud=$(stty -F "$device" speed 2>/dev/null)
    echo "  波特率: $baud"
    
    # 获取数据位
    local databits=""
    if stty -F "$device" -a | grep -q "cs5"; then
        databits="5"
    elif stty -F "$device" -a | grep -q "cs6"; then
        databits="6"
    elif stty -F "$device" -a | grep -q "cs7"; then
        databits="7"
    elif stty -F "$device" -a | grep -q "cs8"; then
        databits="8"
    fi
    echo "  数据位: $databits"
    
    # 获取停止位
    local stopbits="1"
    if stty -F "$device" -a | grep -q "cstopb"; then
        stopbits="2"
    fi
    echo "  停止位: $stopbits"
    
    # 获取校验位
    local parity="none"
    if stty -F "$device" -a | grep -q "parenb"; then
        if stty -F "$device" -a | grep -q "parodd"; then
            parity="odd"
        else
            parity="even"
        fi
    fi
    echo "  校验位: $parity"
    
    # 获取流控制
    local flow="none"
    if stty -F "$device" -a | grep -q "crtscts"; then
        flow="rtscts"
    elif stty -F "$device" -a | grep -q "ixon"; then
        flow="xonxoff"
    fi
    echo "  流控制: $flow"
    
    echo "=========================================="
}

set_config() {
    local device=$1
    local baud=$2
    local databits=$3
    local stopbits=$4
    local parity=$5
    local flow=$6
    
    echo "配置串口: $device"
    
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    local stty_cmd="stty -F $device"
    
    # 设置波特率
    if [[ -n "$baud" ]]; then
        stty_cmd="$stty_cmd $baud"
        echo "  设置波特率: $baud"
    fi
    
    # 设置数据位
    if [[ -n "$databits" ]]; then
        case $databits in
            5) stty_cmd="$stty_cmd cs5" ;;
            6) stty_cmd="$stty_cmd cs6" ;;
            7) stty_cmd="$stty_cmd cs7" ;;
            8) stty_cmd="$stty_cmd cs8" ;;
            *) echo "错误: 无效的数据位: $databits"; return 1 ;;
        esac
        echo "  设置数据位: $databits"
    fi
    
    # 设置停止位
    if [[ -n "$stopbits" ]]; then
        case $stopbits in
            1) stty_cmd="$stty_cmd -cstopb" ;;
            2) stty_cmd="$stty_cmd cstopb" ;;
            *) echo "错误: 无效的停止位: $stopbits"; return 1 ;;
        esac
        echo "  设置停止位: $stopbits"
    fi
    
    # 设置校验位
    if [[ -n "$parity" ]]; then
        case $parity in
            none) stty_cmd="$stty_cmd -parenb" ;;
            odd)  stty_cmd="$stty_cmd parenb parodd" ;;
            even) stty_cmd="$stty_cmd parenb -parodd" ;;
            *) echo "错误: 无效的校验位: $parity"; return 1 ;;
        esac
        echo "  设置校验位: $parity"
    fi
    
    # 设置流控制
    if [[ -n "$flow" ]]; then
        case $flow in
            none)    stty_cmd="$stty_cmd -crtscts -ixon -ixoff" ;;
            rtscts)  stty_cmd="$stty_cmd crtscts -ixon -ixoff" ;;
            xonxoff) stty_cmd="$stty_cmd -crtscts ixon ixoff" ;;
            *) echo "错误: 无效的流控制: $flow"; return 1 ;;
        esac
        echo "  设置流控制: $flow"
    fi
    
    # 执行配置命令
    $stty_cmd raw -echo || {
        echo "错误: 配置失败"
        return 1
    }
    
    echo "配置成功！"
}

reset_config() {
    local device=$1
    
    echo "重置串口配置: $device"
    
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    # 重置为默认配置: 115200 8N1 无流控
    stty -F "$device" 115200 cs8 -cstopb -parenb -crtscts -ixon -ixoff raw -echo || {
        echo "错误: 重置失败"
        return 1
    }
    
    echo "已重置为默认配置: 115200 8N1 无流控"
}

# 默认参数
DEVICE=""
BAUD=""
DATABITS=""
STOPBITS=""
PARITY=""
FLOW=""
SHOW_CONFIG=false
RESET_CONFIG=false

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
        -s|--show)
            SHOW_CONFIG=true
            shift
            ;;
        -r|--reset)
            RESET_CONFIG=true
            shift
            ;;
        --databits)
            DATABITS="$2"
            shift 2
            ;;
        --stopbits)
            STOPBITS="$2"
            shift 2
            ;;
        --parity)
            PARITY="$2"
            shift 2
            ;;
        --flow)
            FLOW="$2"
            shift 2
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

# 执行操作
if [[ "$SHOW_CONFIG" == "true" ]]; then
    show_config "$DEVICE"
elif [[ "$RESET_CONFIG" == "true" ]]; then
    reset_config "$DEVICE"
else
    set_config "$DEVICE" "$BAUD" "$DATABITS" "$STOPBITS" "$PARITY" "$FLOW"
fi
