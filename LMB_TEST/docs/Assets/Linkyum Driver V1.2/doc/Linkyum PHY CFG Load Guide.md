# Linkyum PHY CFG Load Guide

## Instructions for Use

CFG默认不使能，只有当用户需要进行配置优化时可以按照以下说明进行操作

## Copy Files

将linux文件夹里的linkyum.c和cfg文件夹里的linkyum.h复制到linux内核路径如下:

Kernel/drivers/net/phy

## CFG ENABLE

根据具体项目打开需要加载配置优化的使能开关

/* Config Enable Flag */
#define LINKYUM_PHY_LY1211V1_CFG_ENABLE                        0
#define LINKYUM_PHY_LY1211V2_CFG_ENABLE                        0
#define LINKYUM_PHY_LY1241V2_CFG_ENABLE                        0

## Finally

Start compiling





 