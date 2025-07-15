#!/bin/bash
# filepath: uart_sender.sh
# 向串口发送数据的工具

show_usage() {
    echo "用法: hwtest uart send [选项] <设备> [数据]"
    echo ""
    echo "选项:"
    echo "  -d, --device  <device>    指定串口设备 (如: /dev/ttyS0)"
    echo "  -b, --baud    <rate>      波特率 (默认: 115200)"
    echo "  -f, --file    <file>      从文件发送数据"
    echo "  -r, --repeat  <count>     重复发送次数 (默认: 1)"
    echo "  -i, --interval <ms>       发送间隔(毫秒) (默认: 0)"
    echo "  -h, --hex                 以十六进制格式发送"
    echo "  -n, --newline             发送后添加换行符"
    echo "  --help                    显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest uart send /dev/ttyS0 'Hello World'"
    echo "  hwtest uart send -d /dev/ttyS0 -r 5 -i 1000 'test'"
    echo "  hwtest uart send -d /dev/ttyS0 -f test.txt"
    echo "  hwtest uart send -d /dev/ttyS0 -h '48656C6C6F'"
}

send_data() {
    local device=$1
    local data=$2
    local baud=$3
    local hex_mode=$4
    local add_newline=$5
    
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
    
    # 准备发送的数据
    local send_data="$data"
    
    if [[ "$hex_mode" == "true" ]]; then
        # 十六进制模式
        send_data=$(echo -n "$data" | xxd -r -p)
    fi
    
    if [[ "$add_newline" == "true" ]]; then
        send_data="${send_data}\n"
    fi
    
    # 发送数据
    echo -ne "$send_data" > "$device"
    
    echo "已发送到 $device: $data"
}

send_file() {
    local device=$1
    local file=$2
    local baud=$3
    
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件 $file 不存在"
        return 1
    fi
    
    if [[ ! -c "$device" ]]; then
        echo "错误: 设备 $device 不存在或不是字符设备"
        return 1
    fi
    
    # 配置串口参数
    stty -F "$device" "$baud" cs8 -cstopb -parity raw -echo || {
        echo "错误: 无法配置串口 $device"
        return 1
    }
    
    echo "发送文件 $file 到 $device..."
    cat "$file" > "$device"
    echo "文件发送完成"
}

# 默认参数
DEVICE=""
DATA=""
BAUD="115200"
FILE=""
REPEAT=1
INTERVAL=0
HEX_MODE=false
ADD_NEWLINE=false

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
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -r|--repeat)
            REPEAT="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -h|--hex)
            HEX_MODE=true
            shift
            ;;
        -n|--newline)
            ADD_NEWLINE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$DEVICE" && -c "$1" ]]; then
                DEVICE="$1"
            elif [[ -z "$DATA" ]]; then
                DATA="$1"
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

# 执行发送
if [[ -n "$FILE" ]]; then
    # 发送文件
    send_file "$DEVICE" "$FILE" "$BAUD"
elif [[ -n "$DATA" ]]; then
    # 发送数据
    for ((i=1; i<=REPEAT; i++)); do
        echo "第 $i/$REPEAT 次发送:"
        send_data "$DEVICE" "$DATA" "$BAUD" "$HEX_MODE" "$ADD_NEWLINE"
        
        if [[ $i -lt $REPEAT && $INTERVAL -gt 0 ]]; then
            echo "等待 ${INTERVAL}ms..."
            sleep $(echo "scale=3; $INTERVAL/1000" | bc -l)
        fi
    done
else
    echo "错误: 必须指定要发送的数据或文件"
    show_usage
    exit 1
fi
