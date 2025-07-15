# Bist User Guide

## LY1211A Txbist , Rxbist and Bistclr

### Txbist

**Utp** txbist使能发100000个包:

    0x18写0x0000

    0x1a写0x3000

    0x18写0x4000

**Rgmii** txbist使能发100000个包:

    0x18写0x0000

    0x1b写0x3000

    0x18写0x80

**Note:** **0x1a**(自发帧配置寄存器1)和**0x1b**(自发帧配置寄存器2) [14:14]配置自发帧间隙，[13:11]配置自发帧数量，[10:9]配置自发帧长度，详细描述参考Datasheet寄存器描述。

### Rxbist

**Utp** rxbist收包使能打开:

    0x18写0x40

**Utp** rxbist收包数统计:

    0x18写0x440

    Cnt0 = 读0x19

    0x18写0x540

    Cnt1 = 读0x19

    0x18写0x640

    Cnt2 = 读0x19

    0x18写0x740

    Cnt3 = 读0x19

    实际收包数=Cnt1<<16 + Cnt0

    错包数    =Cnt3<<16 + Cnt2

**Rgmii** rxbist收包使能打开:

    0x18写0x8000

**Rgmii** rxbist收包数统计:

    0x18写0x8000

    Cnt0 = 读0x19

    0x18写0x8100

    Cnt1 = 读0x19

    0x18写0x8200

    Cnt2 = 读0x19

    0x18写0x8300

    Cnt3 = 读0x19

    实际收包数=Cnt1<<16 + Cnt0

    错包数    =Cnt3<<16 + Cnt2

### Bistclr

**Utp** bist clear:

    value = 读0x18

    0x18写(value | 0x10)

**Rgmii** bist clear:

    value = 读0x18

    0x18写(value | 0x1000)


## LY1211S Txbist , Rxbist and Bistclr

### Txbist

**Utp** txbist使能发100000个包:

    0x18写0x0000

    0x1a写0x3000

    0x18写0x4000

**Rgmii** txbist使能发100000个包:

    0x18写0x00

    0x1b写0x3000

    0x18写0x80

**Serdes** txbist使能发100000个包: 

    0x18写0x00

    0x1b写0x3000

    0x18写0xc0

**Note: 0x1a**(自发帧配置寄存器1)和**0x1b**(自发帧配置寄存器2) [14:14]配置自发帧间隙，[13:11]配置自发帧数量，[10:9]配置自发帧长度，详细描述参考Datasheet寄存器描述。

### Rxbist

**Utp** rxbist收包使能打开:

    0x18写0x40

**Utp** rxbist收包数统计:

    0x18写0x440

    Cnt0 = 读0x19

    0x18写0x540

    Cnt1 = 读0x19

    0x18写0x640

    Cnt2 = 读0x19

    0x18写0x740

    Cnt3 = 读0x19

    实际收包数=Cnt1<<16 + Cnt0

    错包数    =Cnt3<<16 + Cnt2

**Rgmii** rxbist收包使能打开:

    0x18写0x8000

**Rgmii** rxbist收包数统计:

    0x18写0x8000

    Cnt0 = 读0x19

    0x18写0x8100

    Cnt1 = 读0x19

    0x18写0x8200

    Cnt2 = 读0x19

    0x18写0x8300

    Cnt3 = 读0x19

    实际收包数=Cnt1<<16 + Cnt0

    错包数    =Cnt3<<16 + Cnt2

**Serdes** rxbist收包使能打开: 

    0x18写0xc000

**Serdes** rxbist收包数统计:

    0x18写0xc000

    Cnt0 = 读0x19

    0x18写0xc100

    Cnt1 = 读0x19

    0x18写0xc200

    Cnt2 = 读0x19

    0x18写0xc300

    Cnt3 = 读0x19

    实际收包数=Cnt1<<16 + Cnt0

    错包数    =Cnt3<<16 + Cnt2

### Bistclr

**Utp** bist clear:

    value = 读0x18

    0x18写(value | 0x10)

**Rgmii** bist clear:

    value = 读0x18

    0x18写(value | 0x1000)

**Serdes** bist clear:

    value = 读0x18

    0x18写(value | 0x1000)

 

## LY1241A Txbist , Rxbist and Bistclr

### Txbist

**Utp** txbist使能发100000个包:

    0x1a写0x0000

    0x1a写0xb000

**Note: 0x1a**(自发帧配置寄存器2) [14:14]配置自发帧间隙，[13:11]配置自发帧数量，[10:9]配置自发帧长度，详细描述参考Datasheet寄存器描述。

### Rxbist

**Utp** rxbist收包使能打开:

    0x19写0x8000

**Utp** rxbist收包数统计:

    0x19写0xa000

    Cnt0 = 读0x18

    0x19写0x8000

    Cnt1 = 读0x18

    0x19写0xb000

    Cnt2 = 读0x18

    0x19写0x9000

    Cnt3 = 读0x18

    实际收包数=Cnt0<<16 + Cnt1

    错包数    =Cnt2<<16 + Cnt3

### Bistclr

**Utp** bist clear:

    value = 读0x19

    0x19写(value | 0x4000)



## LY1210A Txbist , Rxbist and Bistclr

### Txbist

**Utp** txbist使能发100000个包:

    0x1a写0x0000

    0x1a写0xb000

**Note: 0x1a**(自发帧配置寄存器2) [14:14]配置自发帧间隙，[13:11]配置自发帧数量，[10:9]配置自发帧长度，详细描述参考Datasheet寄存器描述。

### Rxbist

**Utp** rxbist收包使能打开:

    0x19写0x8000

**Utp** rxbist收包数统计:

    0x19写0xa000

    Cnt0 = 读0x18

    0x19写0x8000

    Cnt1 = 读0x18

    0x19写0xb000

    Cnt2 = 读0x18

    0x19写0x9000

    Cnt3 = 读0x18

    实际收包数=Cnt0<<16 + Cnt1

    错包数    =Cnt2<<16 + Cnt3

### Bistclr

**Utp** bist clear:

    value = 读0x19

    0x19写(value | 0x4000)

 

 