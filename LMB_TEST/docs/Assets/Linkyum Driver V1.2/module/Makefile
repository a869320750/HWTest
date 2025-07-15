# Makefile for building a kernel module
#如果编译异常可以尝试以下命令
# make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- 
MODULE_NAME := linkyum

obj-m := $(MODULE_NAME).o

KSRC := /lib/modules/`uname -r`/build


all:
    make -C $(KSRC) M=$(PWD) modules

clean:
    make -C $(KSRC) M=$(PWD) clean
	