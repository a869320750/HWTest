import serial
import time

def send_command(ser, cmd):
    ser.write((cmd + '\n').encode('utf-8'))
    time.sleep(0.2)  # 等待命令执行

def parse_bno08x_packet(packet):
    """解析19字节的BNO08X数据包"""
    if len(packet) != 19:
        raise ValueError("无效数据包长度，应为19字节")

    # 校验包头
    header = packet[0:2]
    if header != b'\xaa\xaa':
        raise ValueError("无效包头")

    # 字段解析（小端模式）
    index = packet[2]
    yaw = int.from_bytes(packet[3:5], byteorder='little', signed=True) * 0.01
    pitch = int.from_bytes(packet[5:7], byteorder='little', signed=True) * 0.01
    roll = int.from_bytes(packet[7:9], byteorder='little', signed=True) * 0.01
    x_accel = int.from_bytes(packet[9:11], byteorder='little', signed=True)  # mg
    y_accel = int.from_bytes(packet[11:13], byteorder='little', signed=True)
    z_accel = int.from_bytes(packet[13:15], byteorder='little', signed=True)

    # 转换为m/s²（1g = 9.80665 m/s²）
    x_accel_ms2 = x_accel * 0.001 * 9.80665
    y_accel_ms2 = y_accel * 0.001 * 9.80665
    z_accel_ms2 = z_accel * 0.001 * 9.80665

    # 校验和计算
    csum = sum(packet[2:17]) & 0xFFFF  # 计算Index到Reserved的和
    received_csum = int.from_bytes(packet[17:19], byteorder='little')

    return {
        "header": header.hex(),
        "index": index,
        "yaw": round(yaw, 2),
        "pitch": round(pitch, 2),
        "roll": round(roll, 2),
        "acceleration": {
            "x_mg": x_accel,
            "y_mg": y_accel,
            "z_mg": z_accel,
            "x_ms2": round(x_accel_ms2, 3),
            "y_ms2": round(y_accel_ms2, 3),
            "z_ms2": round(z_accel_ms2, 3)
        },
        "checksum_valid": (csum == received_csum)
    }

def read_and_parse_serial_data(port='/dev/ttyS1', baudrate=115200):
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE
        )

        print(f"成功打开串口 {ser.name}")

        data = ser.read(100)
        if not data:
            print("未接收到数据")
            ser.close()
            return None

        hex_data = data.hex()
        print(f"原始数据: {hex_data}")

        start_idx = 0
        while start_idx <= len(data) - 19:
            if data[start_idx:start_idx+2] == b'\xaa\xaa':
                try:
                    packet = data[start_idx:start_idx+19]
                    parsed = parse_bno08x_packet(packet)

                    # 生成打印的数据内容
                    packet_info = f"\n=== 数据包索引 {parsed['index']} ==="
                    packet_info += f"\n偏航角(Yaw): {parsed['yaw']}°"
                    packet_info += f"\n俯仰角(Pitch): {parsed['pitch']}°"
                    packet_info += f"\n翻滚角(Roll): {parsed['roll']}°"
                    packet_info += f"\nX轴加速度: {parsed['acceleration']['x_mg']} mg ({parsed['acceleration']['x_ms2']} m/s²)"
                    packet_info += f"\nY轴加速度: {parsed['acceleration']['y_mg']} mg ({parsed['acceleration']['y_ms2']} m/s²)"
                    packet_info += f"\nZ轴加速度: {parsed['acceleration']['z_mg']} mg ({parsed['acceleration']['z_ms2']} m/s²)"
                    # packet_info += f"\n校验状态: {'有效' if parsed['checksum_valid'] else '无效'}"

                    ser.close()
                    return packet_info
                except ValueError as e:
                    print(f"数据包解析错误: {e}")
                    start_idx += 1
            else:
                start_idx += 1

        ser.close()
        return None

    except serial.SerialException as e:
        print(f"串口错误: {e}")
        return None
    except Exception as e:
        print(f"未知错误: {e}")
        return None

def read_and_parse_loop(ser):
    buffer = b""
    while True:
        data = ser.read(1024)
        if not data:
            continue
        buffer += data
        # 保证缓冲区不会无限增长
        if len(buffer) > 4096:
            buffer = buffer[-4096:]
        start_idx = 0
        while start_idx <= len(buffer) - 19:
            if buffer[start_idx:start_idx+2] == b'\xaa\xaa':
                try:
                    packet = buffer[start_idx:start_idx+19]
                    parsed = parse_bno08x_packet(packet)
                    print(f"\n=== 数据包索引 {parsed['index']} ===")
                    print(f"偏航角(Yaw): {parsed['yaw']}°")
                    print(f"俯仰角(Pitch): {parsed['pitch']}°")
                    print(f"翻滚角(Roll): {parsed['roll']}°")
                    print(f"X轴加速度: {parsed['acceleration']['x_mg']} mg ({parsed['acceleration']['x_ms2']} m/s²)")
                    print(f"Y轴加速度: {parsed['acceleration']['y_mg']} mg ({parsed['acceleration']['y_ms2']} m/s²)")
                    print(f"Z轴加速度: {parsed['acceleration']['z_mg']} mg ({parsed['acceleration']['z_ms2']} m/s²)")
                    start_idx += 19
                except ValueError as e:
                    print(f"数据包解析错误: {e}")
                    start_idx += 1
            else:
                start_idx += 1
        buffer = buffer[start_idx:]

def main():
    ser = serial.Serial('COM9', 1500000, timeout=1)
    print("串口已打开")
    send_command(ser, 'stty -F /dev/ttyS1 speed 115200 cs8 -echo')
    send_command(ser, 'stty -F /dev/ttyS1 speed 115200 cs8 -echo')
    send_command(ser, 'cat /dev/ttyS1')
    read_and_parse_loop(ser)

if __name__ == "__main__":
    main()