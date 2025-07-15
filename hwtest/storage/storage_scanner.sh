#!/bin/bash
# filepath: storage_scanner.sh
# 存储设备扫描工具

show_usage() {
    echo "用法: hwtest storage scan [选项]"
    echo ""
    echo "选项:"
    echo "  -a, --all         显示所有存储设备(包括虚拟设备)"
    echo "  -r, --removable   只显示可移动存储设备"
    echo "  -d, --detail      显示详细信息"
    echo "  -s, --summary     显示设备摘要"
    echo "  --help           显示帮助"
    echo ""
    echo "示例:"
    echo "  hwtest storage scan           # 扫描所有存储设备"
    echo "  hwtest storage scan -r        # 只显示可移动设备"
    echo "  hwtest storage scan -d        # 详细信息"
}

scan_storage_devices() {
    local show_all=$1
    local removable_only=$2
    local detailed=$3
    local summary=$4
    
    echo "========================================"
    echo "存储设备扫描结果"
    echo "========================================"
    
    # 获取所有块设备
    local devices=""
    if [[ "$show_all" == "true" ]]; then
        devices=$(lsblk -dn -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | grep -E 'disk|part')
    else
        devices=$(lsblk -dn -o NAME,SIZE,TYPE,MOUNTPOINT 2>/dev/null | grep 'disk')
    fi
    
    if [[ -z "$devices" ]]; then
        echo "未检测到存储设备"
        return 1
    fi
    
    local device_count=0
    local total_size=0
    
    echo "$devices" | while IFS= read -r line; do
        local device_name=$(echo "$line" | awk '{print $1}')
        local device_size=$(echo "$line" | awk '{print $2}')
        local device_type=$(echo "$line" | awk '{print $3}')
        local mount_point=$(echo "$line" | awk '{print $4}')
        
        # 检查是否为可移动设备
        local is_removable="否"
        if [[ -r "/sys/block/$device_name/removable" ]]; then
            local removable_flag=$(cat "/sys/block/$device_name/removable" 2>/dev/null)
            if [[ "$removable_flag" == "1" ]]; then
                is_removable="是"
            fi
        fi
        
        # 如果只显示可移动设备，跳过非可移动设备
        if [[ "$removable_only" == "true" && "$is_removable" == "否" ]]; then
            continue
        fi
        
        device_count=$((device_count + 1))
        
        echo "----------------------------------------"
        echo "设备: /dev/$device_name"
        echo "大小: $device_size"
        echo "类型: $device_type"
        echo "可移动: $is_removable"
        
        if [[ -n "$mount_point" ]]; then
            echo "挂载点: $mount_point"
        else
            echo "挂载点: 未挂载"
        fi
        
        if [[ "$detailed" == "true" ]]; then
            # 显示详细信息
            echo ""
            echo "详细信息:"
            
            # 文件系统信息
            local fs_info=$(blkid "/dev/$device_name" 2>/dev/null)
            if [[ -n "$fs_info" ]]; then
                echo "  文件系统: $fs_info"
            fi
            
            # 分区信息
            echo "  分区列表:"
            lsblk "/dev/$device_name" -o NAME,SIZE,FSTYPE,MOUNTPOINT 2>/dev/null | sed 's/^/    /'
            
            # 健康信息(如果支持SMART)
            if command -v smartctl >/dev/null 2>&1; then
                local smart_info=$(smartctl -H "/dev/$device_name" 2>/dev/null | grep "SMART overall-health")
                if [[ -n "$smart_info" ]]; then
                    echo "  SMART状态: $smart_info"
                fi
            fi
            
            # 设备详细信息
            if [[ -r "/sys/block/$device_name/device/model" ]]; then
                local model=$(cat "/sys/block/$device_name/device/model" 2>/dev/null | tr -d ' \n')
                if [[ -n "$model" ]]; then
                    echo "  设备型号: $model"
                fi
            fi
            
            if [[ -r "/sys/block/$device_name/device/vendor" ]]; then
                local vendor=$(cat "/sys/block/$device_name/device/vendor" 2>/dev/null | tr -d ' \n')
                if [[ -n "$vendor" ]]; then
                    echo "  制造商: $vendor"
                fi
            fi
        fi
    done
    
    if [[ "$summary" == "true" ]]; then
        echo "========================================"
        echo "扫描摘要:"
        echo "  检测到设备数: $device_count"
        echo "  可移动设备数: $(echo "$devices" | wc -l)"
        echo "  系统时间: $(date)"
        echo "========================================"
    fi
}

# 默认参数
SHOW_ALL=false
REMOVABLE_ONLY=false
DETAILED=false
SUMMARY=true

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            SHOW_ALL=true
            shift
            ;;
        -r|--removable)
            REMOVABLE_ONLY=true
            shift
            ;;
        -d|--detail)
            DETAILED=true
            shift
            ;;
        -s|--summary)
            SUMMARY=true
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

# 执行扫描
scan_storage_devices "$SHOW_ALL" "$REMOVABLE_ONLY" "$DETAILED" "$SUMMARY"
