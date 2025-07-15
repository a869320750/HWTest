#!/bin/bash
# filepath: storage_speed.sh
# 存储设备速度测试工具

show_usage() {
    echo "用法: hwtest storage speed [选项] <设备>"
    echo ""
    echo "选项:"
    echo "  -d, --device <device>    指定存储设备 (如: /dev/sda)"
    echo "  -s, --size <size>        测试文件大小 (默认: 100M)"
    echo "  -c, --count <count>      测试次数 (默认: 3)"
    echo "  -t, --type <type>        测试类型: read|write|both (默认: both)"
    echo "  -f, --file               文件系统测试模式 (更安全)"
    echo "  --help                   显示帮助"
    echo ""
    echo "⚠️  警告: 直接设备测试会破坏数据，建议使用 -f 选项"
    echo ""
    echo "示例:"
    echo "  hwtest storage speed -d /dev/sda -f        # 文件系统测试"
    echo "  hwtest storage speed -d /dev/sda -s 50M    # 直接设备测试"
    echo "  hwtest storage speed -d /dev/sda -t read   # 只测读取"
}

test_filesystem_speed() {
    local device=$1
    local size=$2
    local count=$3
    local test_type=$4
    
    # 找到设备的挂载点
    local mount_point=$(df "$device" 2>/dev/null | tail -1 | awk '{print $6}')
    if [[ -z "$mount_point" ]]; then
        echo "错误: 设备 $device 未挂载"
        return 1
    fi
    
    echo "=========================================="
    echo "文件系统速度测试: $device"
    echo "挂载点: $mount_point"
    echo "测试大小: $size"
    echo "测试次数: $count"
    echo "=========================================="
    
    local test_file="$mount_point/hwtest_speed_test.tmp"
    local total_write_speed=0
    local total_read_speed=0
    local write_count=0
    local read_count=0
    
    for ((i=1; i<=count; i++)); do
        echo "第 $i/$count 次测试..."
        
        # 写入测试
        if [[ "$test_type" == "write" || "$test_type" == "both" ]]; then
            echo "  写入测试..."
            local write_result=$(dd if=/dev/zero of="$test_file" bs=1M count=${size%M} 2>&1)
            local write_speed=$(echo "$write_result" | grep -o '[0-9.]\+ MB/s' | tail -1 | cut -d' ' -f1)
            
            if [[ -n "$write_speed" ]]; then
                echo "    写入速度: ${write_speed} MB/s"
                total_write_speed=$(echo "$total_write_speed + $write_speed" | bc -l)
                write_count=$((write_count + 1))
            fi
        fi
        
        # 清除缓存
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        
        # 读取测试
        if [[ "$test_type" == "read" || "$test_type" == "both" ]] && [[ -f "$test_file" ]]; then
            echo "  读取测试..."
            local read_result=$(dd if="$test_file" of=/dev/null bs=1M 2>&1)
            local read_speed=$(echo "$read_result" | grep -o '[0-9.]\+ MB/s' | tail -1 | cut -d' ' -f1)
            
            if [[ -n "$read_speed" ]]; then
                echo "    读取速度: ${read_speed} MB/s"
                total_read_speed=$(echo "$total_read_speed + $read_speed" | bc -l)
                read_count=$((read_count + 1))
            fi
        fi
        
        echo ""
    done
    
    # 清理测试文件
    rm -f "$test_file"
    
    # 计算平均速度
    echo "=========================================="
    echo "测试结果摘要:"
    
    if [[ $write_count -gt 0 ]]; then
        local avg_write=$(echo "scale=2; $total_write_speed / $write_count" | bc -l)
        echo "  平均写入速度: ${avg_write} MB/s"
    fi
    
    if [[ $read_count -gt 0 ]]; then
        local avg_read=$(echo "scale=2; $total_read_speed / $read_count" | bc -l)
        echo "  平均读取速度: ${avg_read} MB/s"
    fi
    
    echo "=========================================="
}

test_device_speed() {
    local device=$1
    local size=$2
    local count=$3
    local test_type=$4
    
    echo "⚠️  警告: 直接设备测试会破坏数据!"
    echo "设备: $device"
    echo "确认继续? (输入 'YES' 确认): "
    read -r confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        echo "已取消测试"
        return 1
    fi
    
    echo "=========================================="
    echo "直接设备速度测试: $device"
    echo "测试大小: $size"
    echo "测试次数: $count"
    echo "=========================================="
    
    # 检查设备是否存在
    if [[ ! -b "$device" ]]; then
        echo "错误: $device 不是一个块设备"
        return 1
    fi
    
    # 获取设备大小
    local device_size=$(blockdev --getsize64 "$device" 2>/dev/null)
    if [[ -n "$device_size" ]]; then
        local size_gb=$((device_size / 1024 / 1024 / 1024))
        echo "设备大小: ${size_gb}GB"
    fi
    
    for ((i=1; i<=count; i++)); do
        echo "第 $i/$count 次测试..."
        
        # 写入测试 (危险操作!)
        if [[ "$test_type" == "write" || "$test_type" == "both" ]]; then
            echo "  ⚠️  写入测试 (会破坏数据)..."
            local write_result=$(dd if=/dev/zero of="$device" bs=1M count=${size%M} 2>&1)
            local write_speed=$(echo "$write_result" | grep -o '[0-9.]\+ MB/s' | tail -1 | cut -d' ' -f1)
            echo "    写入速度: ${write_speed} MB/s"
        fi
        
        # 读取测试
        if [[ "$test_type" == "read" || "$test_type" == "both" ]]; then
            echo "  读取测试..."
            local read_result=$(dd if="$device" of=/dev/null bs=1M count=${size%M} 2>&1)
            local read_speed=$(echo "$read_result" | grep -o '[0-9.]\+ MB/s' | tail -1 | cut -d' ' -f1)
            echo "    读取速度: ${read_speed} MB/s"
        fi
        
        echo ""
    done
}

# 默认参数
DEVICE=""
SIZE="100M"
COUNT="3"
TEST_TYPE="both"
FILE_MODE=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -f|--file)
            FILE_MODE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            if [[ -z "$DEVICE" && -b "$1" ]]; then
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

# 检查必需参数
if [[ -z "$DEVICE" ]]; then
    echo "错误: 请指定存储设备"
    show_usage
    exit 1
fi

# 检查bc命令
if ! command -v bc >/dev/null 2>&1; then
    echo "警告: 未找到bc命令，平均值计算可能不准确"
fi

# 执行测试
if [[ "$FILE_MODE" == "true" ]]; then
    test_filesystem_speed "$DEVICE" "$SIZE" "$COUNT" "$TEST_TYPE"
else
    test_device_speed "$DEVICE" "$SIZE" "$COUNT" "$TEST_TYPE"
fi
