#!/bin/bash
# filepath: uart_scanner.sh
# 扫描系统中所有可用的串口设备

uart_scanner() {
    echo "=========================================="
    echo "扫描系统串口设备..."
    echo "=========================================="
    
    echo "1. 检查 /dev/tty* 设备:"
    echo "----------------------------------------"
    SERIAL_DEVICES=$(ls /dev/ttyS* /dev/ttyUSB* /dev/ttyACM* /dev/ttyAMA* 2>/dev/null | sort)
    
    if [[ -z "$SERIAL_DEVICES" ]]; then
        echo "未发现串口设备"
    else
        for device in $SERIAL_DEVICES; do
            if [[ -c "$device" ]]; then
                printf "  %-15s : " "$(basename $device)"
                if [[ -r "$device" && -w "$device" ]]; then
                    echo "可用 ✓"
                else
                    echo "权限不足 ✗"
                fi
            fi
        done
    fi
    
    echo ""
    echo "2. 检查USB串口设备:"
    echo "----------------------------------------"
    USB_SERIAL=$(lsusb | grep -E "Serial|UART|CP210|FT232|CH34")
    if [[ -n "$USB_SERIAL" ]]; then
        echo "$USB_SERIAL"
    else
        echo "未发现USB串口设备"
    fi
    
    echo ""
    echo "3. 检查内核串口驱动:"
    echo "----------------------------------------"
    SERIAL_DRIVERS=$(lsmod | grep -E "serial|uart|usb.*serial")
    if [[ -n "$SERIAL_DRIVERS" ]]; then
        echo "$SERIAL_DRIVERS"
    else
        echo "未加载串口驱动模块"
    fi
    
    echo ""
    echo "4. 检查设备树中的串口配置:"
    echo "----------------------------------------"
    if [[ -d "/proc/device-tree" ]]; then
        UART_NODES=$(find /proc/device-tree -name "*uart*" -o -name "*serial*" 2>/dev/null | head -10)
        if [[ -n "$UART_NODES" ]]; then
            for node in $UART_NODES; do
                echo "  $node"
            done
        else
            echo "设备树中未找到UART节点"
        fi
    fi
    
    echo ""
    echo "5. 检查dmesg中的串口信息:"
    echo "----------------------------------------"
    UART_LOGS=$(dmesg | grep -i -E "uart|serial|tty" | tail -5)
    if [[ -n "$UART_LOGS" ]]; then
        echo "$UART_LOGS"
    else
        echo "dmesg中未找到相关信息"
    fi
    
    echo ""
    echo "扫描完成！"
    echo "=========================================="
}

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
    echo "警告: 建议以root权限运行以获得完整信息"
    echo "使用: sudo hwtest uart scan"
    echo ""
fi

uart_scanner
