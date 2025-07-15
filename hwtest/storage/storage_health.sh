#!/bin/bash
# filepath: storage_health.sh
# 存储设备健康检查工具

show_usage() {
    echo "用法: hwtest storage health [选项] [设备]"
    echo ""
    echo "选项:"
    echo "  -d, --device <device>    指定存储设备 (如: /dev/sda)"
    echo "  -a, --all               检查所有存储设备"
    echo "  -s, --smart             显示SMART详细信息"
    echo "  -t, --test              执行SMART自检"
    echo "  --help                  显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest storage health -a        # 检查所有设备"
    echo "  hwtest storage health -d /dev/sda -s  # 详细SMART信息"
    echo "  hwtest storage health -d /dev/sda -t  # 执行自检"
}

check_smart_support() {
    if ! command -v smartctl >/dev/null 2>&1; then
        echo "⚠️  未找到smartctl工具，请安装smartmontools包"
        echo "   Ubuntu/Debian: apt-get install smartmontools"
        echo "   CentOS/RHEL: yum install smartmontools"
        return 1
    fi
    return 0
}

check_device_health() {
    local device=$1
    local show_smart=$2
    local run_test=$3
    
    echo "=========================================="
    echo "设备健康检查: $device"
    echo "=========================================="
    
    # 检查设备是否存在
    if [[ ! -b "$device" ]]; then
        echo "❌ 错误: $device 不是一个块设备"
        return 1
    fi
    
    # 基本设备信息
    echo "1. 基本信息:"
    local device_info=$(lsblk "$device" -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null)
    if [[ -n "$device_info" ]]; then
        echo "$device_info" | sed 's/^/   /'
    fi
    
    # 设备型号和制造商
    local device_name=$(basename "$device")
    if [[ -r "/sys/block/$device_name/device/model" ]]; then
        local model=$(cat "/sys/block/$device_name/device/model" 2>/dev/null | tr -d ' \n')
        echo "   型号: $model"
    fi
    
    if [[ -r "/sys/block/$device_name/device/vendor" ]]; then
        local vendor=$(cat "/sys/block/$device_name/device/vendor" 2>/dev/null | tr -d ' \n')
        echo "   制造商: $vendor"
    fi
    
    echo ""
    
    # SMART支持检查
    echo "2. SMART支持检查:"
    if ! check_smart_support; then
        echo "   ❌ SMART工具不可用"
        return 1
    fi
    
    local smart_support=$(smartctl -i "$device" 2>/dev/null | grep "SMART support is")
    if [[ -n "$smart_support" ]]; then
        echo "   $smart_support"
    else
        echo "   ⚠️  无法确定SMART支持状态"
    fi
    
    # SMART健康状态
    echo ""
    echo "3. SMART健康状态:"
    local health_status=$(smartctl -H "$device" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        local overall_health=$(echo "$health_status" | grep "SMART overall-health" | cut -d: -f2 | tr -d ' ')
        case "$overall_health" in
            "PASSED")
                echo "   ✅ 健康状态: 良好"
                ;;
            "FAILED")
                echo "   ❌ 健康状态: 故障"
                ;;
            *)
                echo "   ⚠️  健康状态: $overall_health"
                ;;
        esac
    else
        echo "   ⚠️  无法获取SMART健康状态"
    fi
    
    # 温度信息
    echo ""
    echo "4. 温度信息:"
    local temp_info=$(smartctl -A "$device" 2>/dev/null | grep -i temperature)
    if [[ -n "$temp_info" ]]; then
        echo "$temp_info" | sed 's/^/   /'
    else
        echo "   ⚠️  无温度信息"
    fi
    
    # 使用时间和通电次数
    echo ""
    echo "5. 使用统计:"
    local power_on_hours=$(smartctl -A "$device" 2>/dev/null | grep "Power_On_Hours" | awk '{print $10}')
    if [[ -n "$power_on_hours" ]]; then
        local days=$((power_on_hours / 24))
        echo "   通电时间: $power_on_hours 小时 (约 $days 天)"
    fi
    
    local power_cycle=$(smartctl -A "$device" 2>/dev/null | grep "Power_Cycle_Count" | awk '{print $10}')
    if [[ -n "$power_cycle" ]]; then
        echo "   开机次数: $power_cycle 次"
    fi
    
    # 错误计数
    echo ""
    echo "6. 错误统计:"
    local error_count=$(smartctl -l error "$device" 2>/dev/null | grep "No Errors Logged")
    if [[ -n "$error_count" ]]; then
        echo "   ✅ 无错误日志"
    else
        local error_summary=$(smartctl -l error "$device" 2>/dev/null | head -10)
        echo "   ⚠️  发现错误日志:"
        echo "$error_summary" | sed 's/^/      /'
    fi
    
    # 详细SMART信息
    if [[ "$show_smart" == "true" ]]; then
        echo ""
        echo "7. 详细SMART属性:"
        echo "----------------------------------------"
        smartctl -A "$device" 2>/dev/null | sed 's/^/   /'
        echo "----------------------------------------"
    fi
    
    # 执行自检
    if [[ "$run_test" == "true" ]]; then
        echo ""
        echo "8. 执行SMART自检:"
        echo "   启动短自检..."
        local test_result=$(smartctl -t short "$device" 2>/dev/null)
        echo "$test_result" | sed 's/^/   /'
        
        echo "   注意: 自检需要时间完成，可稍后用以下命令查看结果:"
        echo "   smartctl -l selftest $device"
    fi
    
    echo "=========================================="
}

check_all_devices() {
    local show_smart=$1
    local run_test=$2
    
    echo "检查所有存储设备的健康状况..."
    echo ""
    
    # 获取所有磁盘设备
    local devices=$(lsblk -dn -o NAME,TYPE 2>/dev/null | grep 'disk' | awk '{print "/dev/"$1}')
    
    if [[ -z "$devices" ]]; then
        echo "未找到磁盘设备"
        return 1
    fi
    
    local device_count=0
    local healthy_count=0
    
    for device in $devices; do
        device_count=$((device_count + 1))
        
        if check_device_health "$device" "$show_smart" "$run_test"; then
            healthy_count=$((healthy_count + 1))
        fi
        
        echo ""
    done
    
    echo "========================================"
    echo "健康检查摘要:"
    echo "  检查设备数: $device_count"
    echo "  健康设备数: $healthy_count"
    echo "  异常设备数: $((device_count - healthy_count))"
    echo "========================================"
}

# 默认参数
DEVICE=""
CHECK_ALL=false
SHOW_SMART=false
RUN_TEST=false

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -a|--all)
            CHECK_ALL=true
            shift
            ;;
        -s|--smart)
            SHOW_SMART=true
            shift
            ;;
        -t|--test)
            RUN_TEST=true
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

# 执行健康检查
if [[ "$CHECK_ALL" == "true" ]]; then
    check_all_devices "$SHOW_SMART" "$RUN_TEST"
elif [[ -n "$DEVICE" ]]; then
    check_device_health "$DEVICE" "$SHOW_SMART" "$RUN_TEST"
else
    echo "请指定要检查的设备或使用 --all 选项"
    show_usage
    exit 1
fi
