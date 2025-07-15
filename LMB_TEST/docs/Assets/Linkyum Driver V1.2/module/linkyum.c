/****************************************************************************
 *       Copyright (c) 2023 Shanghai Linkyum Microelectronics Co.           *                      
*****************************************************************************                                                                 
 * drivers/net/phy/linkyum.c
 * Description : Driver for LY1211A LY1211S LY1241A LY1241BPHYs.
 * Version : V0.7 Fixed an issue where the network cannot link
 *           V0.8 Follow link to switch Page automatically in mode 2
 *           V0.9 Adapts to ly1211a wol functions and 1000M utp optimise
 *           V0.10 There is a probability that the optimized phy will fail to link and add ly1210 driver
 *           V1.0 Optimize 125M clkout and add 1y1211 cfg function
 *           V1.1 Optimized adaptation 1y1241 cfg function
*****************************************************************************/
#include <linux/kernel.h>
#include <linux/string.h>
#include <linux/errno.h>
#include <linux/unistd.h>
#include <linux/interrupt.h>
#include <linux/init.h>
#include <linux/delay.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/skbuff.h>
#include <linux/spinlock.h>
#include <linux/mm.h>
#include <linux/module.h>
#include <linux/ethtool.h>
#include <linux/phy.h>
#include <linux/of.h>
#include <linux/mii.h>
#include <linux/io.h>
#include <asm/irq.h>
#include <linux/uaccess.h>

#ifndef LINUX_VERSION_CODE
#include <linux/version.h>
#else
#define KERNEL_VERSION(a, b, c) (((a) << 16) + ((b) << 8) + (c))
#endif


/* WOL Enable Flag: 
 * disable by default to enable system WOL feature of phy
 * please define this phy to 1 otherwise, define it to 0.
 */
#define LINKYUM_PHY_WOL_FEATURE_ENABLE                         0
#define LINKYUM_PHY_WOL_PASSWD_ENABLE                          0

#define LINKYUM_PHY_MODE_SET_ENABLE                            0
#define LINKYUM_PHY_RXC_DELAY_SET_ENABLE                       0
#define LINKYUM_PHY_RXC_DELAY_VAL                              0x00
#define LINKYUM_PHY_CLK_OUT_125M_ENABLE                        1
#define LINKYUM_PHY_LINK_OPT_ENABLE                            0


/* Config Enable Flag */
#define LINKYUM_PHY_LY1211V1_CFG_ENABLE                        0
#define LINKYUM_PHY_LY1211V2_CFG_ENABLE                        0
#define LINKYUM_PHY_LY1241V2_CFG_ENABLE                        0

#if LINKYUM_PHY_LY1211V1_CFG_ENABLE || LINKYUM_PHY_LY1211V2_CFG_ENABLE || \
    LINKYUM_PHY_LY1241V2_CFG_ENABLE
#include "linkyum.h"
#endif

#define LYPHY_GLB_DISABLE                                      0
#define LYPHY_GLB_ENABLE                                       1
#define LYPHY_LINK_DOWN                                        0
#define LYPHY_LINK_UP                                          1
/* Mask used for ID comparisons */
#define LINKYUM_PHY_ID_MASK                                    0xffffffff

/* LY1211 PHY IDs */
#define LY1210_PHY_ID                                          0xADB40400
/* LY1211 PHY IDs */
#define LY1211_PHY_ID                                          0xADB40412
/* LY1141 PHY IDs */
#define LY1241_PHY_ID                                          0xADB40411

/*LY1211 PHY LED */
#define LY1211_EXTREG_LED0                                     0x1E33   // 0
#define LY1211_EXTREG_LED1                                     0x1E34   // 00101111
#define LY1211_EXTREG_LED2                                     0x1E35   // 0x40
/*LY1241 PHY BX LED */
#define LY1241_EXTREG_LEDCTRL                                  0x0621   
#define LY1241_EXTREG_LED0_1                                   0x0700   
#define LY1241_EXTREG_LED0_2                                   0x0701
#define LY1241_EXTREG_LED1_1                                   0x0702 
#define LY1241_EXTREG_LED1_2                                   0x0703    
#define LY1241_EXTREG_LED2_1                                   0x0706
#define LY1241_EXTREG_LED2_2                                   0x0707
#define LY1241_EXTREG_LED3_1                                   0x0708
#define LY1241_EXTREG_LED3_2                                   0x0709  
#define LY1241_EXTREG_LED4_1                                   0x070C   
#define LY1241_EXTREG_LED4_2                                   0x070D
#define LY1241_EXTREG_LED5_1                                   0x070E 
#define LY1241_EXTREG_LED5_2                                   0x070F  
#define LY1241_EXTREG_LED6_1                                   0x0712
#define LY1241_EXTREG_LED6_2                                   0x0713
#define LY1241_EXTREG_LED7_1                                   0x0714
#define LY1241_EXTREG_LED7_2                                   0x0715

/* PHY MODE OPSREG*/
#define LY1211_EXTREG_GET_PORT_PHY_MODE                        0x062B   
#define LY1211_EXTREG_PHY_MODE_MASK                            0x0070  
/* Magic Packet MAC address registers */
#define LINKYUM_MAGIC_PACKET_MAC_ADDR                          0x0229            
/* Magic Packet MAC Passwd registers */
#define LINKYUM_MAGIC_PACKET_PASSWD_ADDR                       0x022F   
#define LINKYUM_PHY_WOL_PULSE_MODE_SET                         0x062a

/* Magic Packet MAC Passwd Val*/
#define LINKYUM_MAGIC_PACKET_PASSWD1                           0x11 
#define LINKYUM_MAGIC_PACKET_PASSWD2                           0x22
#define LINKYUM_MAGIC_PACKET_PASSWD3                           0x33
#define LINKYUM_MAGIC_PACKET_PASSWD4                           0x44 
#define LINKYUM_MAGIC_PACKET_PASSWD5                           0x55 
#define LINKYUM_MAGIC_PACKET_PASSWD6                           0x66 

/* Linyum wol config register */
#define LINKYUM_WOL_CFG_REG0                                   0x0220
#define LINKYUM_WOL_CFG_REG1                                   0x0221
#define LINKYUM_WOL_CFG_REG2                                   0x0222
#define LINKYUM_WOL_STA_REG                                    0x0223
/* 8 PHY MODE */
#define LY1211_EXTREG_PHY_MODE_UTP_TO_RGMII                    0x00  
#define LY1211_EXTREG_PHY_MODE_FIBER_TO_RGMII                  0x10  
#define LY1211_EXTREG_PHY_MODE_UTP_OR_FIBER_TO_RGMII           0x20  
#define LY1211_EXTREG_PHY_MODE_UTP_TO_SGMII                    0x30  
#define LY1211_EXTREG_PHY_MODE_SGMII_PHY_TO_RGMII_MAC          0x40  
#define LY1211_EXTREG_PHY_MODE_SGMII_MAC_TO_RGMII_PHY          0x50  
#define LY1211_EXTREG_PHY_MODE_UTP_TO_FIBER_AUTO               0x60  
#define LY1211_EXTREG_PHY_MODE_UTP_TO_FIBER_FORCE              0x70  

/* PHY EXTRW OPSREG */
#define LY1211_EXTREG_ADDR                                     0x0E
#define LY1211_EXTREG_DATA                                     0x0D
/* PHY PAGE SPACE */
#define LYPHY_REG_UTP_SPACE                                    0
#define LYPHY_REG_FIBER_SPACE                                  1

/* PHY PAGE SELECT */
#define LY1211_EXTREG_PHY_MODE_PAGE_SELECT                     0x0016
#define LYPHY_REG_UTP_SPACE_SETADDR                            0x0000
#define LYPHY_REG_FIBER_SPACE_SETADDR                          0x0100
//utp
#define UTP_REG_PAUSE_CAP                                      0x0400    /* Can pause                   */
#define UTP_REG_PAUSE_ASYM                                     0x0800    /* Can pause asymetrically     */
//fiber
#define FIBER_REG_PAUSE_CAP                                    0x0080    /* Can pause                   */
#define FIBER_REG_PAUSE_ASYM                                   0x0100    /* Can pause asymetrically     */

/* specific status register */
#define LINKYUM_SPEC_REG                                       0x0011

/* Interrupt Enable Register */
#define LINKYUM_INTR_REG                                       0x0017 
/* Phy Patch Register */
#define LY_CFG_INIT                                            0xC460
#define LY_CFG_WAIT                                            0xC45C
#define LY_CFG_EPHY_INIT                                       0xC413
#define LY_CFG_ADDR                                            0xC800
#define LY_CFG_ENABLE                                          0xC45D
#define LY_CFG_ENABLE_ACK                                      0xC45E

/* WOL TYPE */
#define LINKYUM_WOL_TYPE                                       BIT(0)
/* WOL Pulse Width */
#define LINKYUM_WOL_WIDTH1                                     BIT(1)
#define LINKYUM_WOL_WIDTH2                                     BIT(2)
/* WOL dest addr check enable */
#define LINKYUM_WOL_SECURE_CHECK                               BIT(5)
/* WOL crc check enable */
#define LINKYUM_WOL_CRC_CHECK                                  BIT(4)
/* WOL dest addr check enable */
#define LINKYUM_WOL_DESTADDR_CHECK                             BIT(5)
/* WOL Event Interrupt Enable */
#define LINKYUM_WOL_INTR_EN                                    BIT(2)
/* WOL Enable */
#define LINKYUM_WOL_EN                                         BIT(7)

#define LINKYUM_WOL_RESTARTANEG                                BIT(9)
/* GET PHY MODE */
#define LYPHY_MODE_CURR                                        lyphy_get_port_type(phydev)

enum linkyum_port_type_e
{
    LYPHY_PORT_TYPE_UTP,
    LYPHY_PORT_TYPE_FIBER,
    LYPHY_PORT_TYPE_COMBO,
    LYPHY_PORT_TYPE_EXT
};
enum linkyum_wol_type_e
{
    LYPHY_WOL_TYPE_LEVEL,
    LYPHY_WOL_TYPE_PULSE,
    LYPHY_WOL_TYPE_EXT
};

enum linkyum_wol_width_e
{
    LYPHY_WOL_WIDTH_84MS,
    LYPHY_WOL_WIDTH_168MS,
    LYPHY_WOL_WIDTH_336MS,
    LYPHY_WOL_WIDTH_672MS,
    LYPHY_WOL_WIDTH_EXT
};

typedef struct linkyum_wol_cfg_s
{
    int wolen;
    int type;
    int width;
    int secure;
    int checkcrc;
    int checkdst;
}linkyum_wol_cfg_t;

#if (KERNEL_VERSION(5, 5, 0) > LINUX_VERSION_CODE)
static inline void phy_lock_mdio_bus(struct phy_device *phydev)
{
#if (KERNEL_VERSION(4, 5, 0) > LINUX_VERSION_CODE)
    mutex_lock(&phydev->bus->mdio_lock);
#else
    mutex_lock(&phydev->mdio.bus->mdio_lock);
#endif
} 

static inline void phy_unlock_mdio_bus(struct phy_device *phydev)
{
#if (KERNEL_VERSION(4, 5, 0) > LINUX_VERSION_CODE)
    mutex_unlock(&phydev->bus->mdio_lock);
#else
    mutex_unlock(&phydev->mdio.bus->mdio_lock);
#endif
}
#endif

#if (KERNEL_VERSION(4, 16, 0) > LINUX_VERSION_CODE)
static inline int __phy_read(struct phy_device *phydev, u32 regnum)
{
#if (KERNEL_VERSION(4, 5, 0) > LINUX_VERSION_CODE)
    struct mii_bus *bus = phydev->bus;
    int addr = phydev->addr;
    return bus->read(bus, phydev->addr, regnum);
#else
    struct mii_bus *bus = phydev->mdio.bus;
    int addr = phydev->mdio.addr;
#endif
    return bus->read(bus, addr, regnum);
}

static inline int __phy_write(struct phy_device *phydev, u32 regnum, u16 val)
{
#if (KERNEL_VERSION(4, 5, 0) > LINUX_VERSION_CODE)
    struct mii_bus *bus = phydev->bus;
    int addr = phydev->addr;
#else
    struct mii_bus *bus = phydev->mdio.bus;
    int addr = phydev->mdio.addr;
#endif
    return bus->write(bus, addr, regnum, val);
}
#endif

#if (KERNEL_VERSION(4, 12, 0) <= LINUX_VERSION_CODE) && (KERNEL_VERSION(4, 16, 0) > LINUX_VERSION_CODE)
static int genphy_read_mmd_unsupported(struct phy_device *phdev, int devad, u16 regnum)
{
    return -EOPNOTSUPP;
}

static int genphy_write_mmd_unsupported(struct phy_device *phdev, int devnum,
                u16 regnum, u16 val)
{
    return -EOPNOTSUPP;
}
#endif

static int ly1241_phy_read(struct phy_device *phydev, u32 regnum)
{
    int ret, val, oldval = 0;
    
    phy_lock_mdio_bus(phydev);

    ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
    if (ret < 0) 
        goto err_handle;
    oldval = ret;

    ret = __phy_read(phydev, regnum);
    if (ret < 0) 
        goto err_handle;
    val = ret;

    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) 
        goto err_handle;
    ret = val;
    
err_handle:
    phy_unlock_mdio_bus(phydev);
    return ret;
}

// static int ly1241_phy_write(struct phy_device *phydev, u32 regnum, u16 val)
// {
//     int ret, oldval = 0;

//     phy_lock_mdio_bus(phydev);

//     ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
//     if (ret < 0) 
//         goto err_handle;
//     oldval = ret;

//     ret = __phy_write(phydev, regnum, val);
//     if(ret<0)
//         goto err_handle;

//     ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
//     if (ret < 0) 
//         goto err_handle;

// err_handle:
//     phy_unlock_mdio_bus(phydev);
//     return ret;
// }

static int ly1211_phy_ext_read(struct phy_device *phydev, u32 regnum)
{
    int ret, val, oldpage = 0, oldval = 0;

    phy_lock_mdio_bus(phydev);

    ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
    if (ret < 0) 
        goto err_handle;
    oldval = ret;

    /* Force change to utp page */
    ret = __phy_read(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT);//get old page
    if (ret < 0) 
        goto err_handle;
    oldpage = ret;

    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, LYPHY_REG_UTP_SPACE_SETADDR);
    if (ret < 0)
        goto err_handle;

    /* Default utp ext rw */
    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, regnum);
    if (ret < 0)
        goto err_handle;

    ret = __phy_read(phydev, LY1211_EXTREG_DATA);
    if (ret < 0)
        goto err_handle;
    val = ret;

    /* Recover to old page */
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, oldpage);
    if (ret < 0) 
        goto err_handle;

    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) 
        goto err_handle;
    ret = val;

err_handle:
    phy_unlock_mdio_bus(phydev);
    return ret;
}

static int ly1211_phy_ext_write(struct phy_device *phydev, u32 regnum, u16 val)
{
    int ret, oldpage = 0, oldval = 0;

    phy_lock_mdio_bus(phydev);

    ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
    if (ret < 0) 
        goto err_handle;
    oldval = ret;

    /* Force change to utp page */
    ret = __phy_read(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT); //get old page
    if (ret < 0)
        goto err_handle;
    oldpage = ret;

    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, LYPHY_REG_UTP_SPACE_SETADDR);
    if (ret < 0)
        goto err_handle;

    /* Default utp ext rw */
    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, regnum);
    if (ret < 0)
        goto err_handle;

    ret = __phy_write(phydev, LY1211_EXTREG_DATA, val);
    if (ret < 0)
        goto err_handle;

    /* Recover to old page */
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, oldpage);
    if (ret < 0) 
        goto err_handle;

    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) 
        goto err_handle;

err_handle:
    phy_unlock_mdio_bus(phydev);
    return ret;

}

static int linkyum_phy_select_reg_page(struct phy_device *phydev, int space)
{
    int ret;
    if (space == LYPHY_REG_UTP_SPACE)
        ret = phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, LYPHY_REG_UTP_SPACE_SETADDR);
    else
        ret = phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, LYPHY_REG_FIBER_SPACE_SETADDR);
    return ret;
}

static int linkyum_phy_get_reg_page(struct phy_device *phydev)
{
    return phy_read(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT);
}

static int linkyum_phy_ext_read(struct phy_device *phydev, u32 regnum)
{
    return ly1211_phy_ext_read(phydev, regnum);
}


static int linkyum_phy_ext_write(struct phy_device *phydev, u32 regnum, u16 val)
{
    return ly1211_phy_ext_write(phydev, regnum, val);
}

static int lyphy_page_read(struct phy_device *phydev, int page, u32 regnum)
{
    int ret, val, oldpage = 0, oldval = 0;
    
    phy_lock_mdio_bus(phydev);

    ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
    if (ret < 0) 
        goto err_handle;
    oldval = ret;

    ret = __phy_read(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT);
    if (ret < 0) 
        goto err_handle;
    oldpage = ret;

    //Select page
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, (page << 8));
    if (ret < 0) 
        goto err_handle;

    ret = __phy_read(phydev, regnum);
    if (ret < 0) 
        goto err_handle;
    val = ret;

    /* Recover to old page */
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, oldpage);
    if (ret < 0) 
        goto err_handle;

    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) 
        goto err_handle;
    ret = val;
    
err_handle:
    phy_unlock_mdio_bus(phydev);
    return ret;
}

static int lyphy_page_write(struct phy_device *phydev, int page, u32 regnum, u16 value)
{
    int ret, oldpage = 0, oldval = 0;

    phy_lock_mdio_bus(phydev);

    ret = __phy_read(phydev, LY1211_EXTREG_ADDR);
    if (ret < 0) 
        goto err_handle;
    oldval = ret;

    ret = __phy_read(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT);
    if (ret < 0) 
        goto err_handle;
    oldpage = ret;

    //Select page
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, (page << 8));
    if(ret<0)
        goto err_handle;

    ret = __phy_write(phydev, regnum, value);
    if(ret<0)
        goto err_handle;

    /* Recover to old page */
    ret = __phy_write(phydev, LY1211_EXTREG_PHY_MODE_PAGE_SELECT, oldpage);
    if (ret < 0)
        goto err_handle;

    ret = __phy_write(phydev, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) 
        goto err_handle;
        
err_handle:
    phy_unlock_mdio_bus(phydev);
    return ret;
}

//get port type
static int lyphy_get_port_type(struct phy_device *phydev)
{
    int ret, mode;

    ret = linkyum_phy_ext_read(phydev, LY1211_EXTREG_GET_PORT_PHY_MODE);
    if (ret < 0)
        return ret;
    ret &= LY1211_EXTREG_PHY_MODE_MASK;

    if (ret == LY1211_EXTREG_PHY_MODE_UTP_TO_RGMII || 
        ret == LY1211_EXTREG_PHY_MODE_UTP_TO_SGMII) {
        mode = LYPHY_PORT_TYPE_UTP;
    } else if (ret == LY1211_EXTREG_PHY_MODE_FIBER_TO_RGMII || 
        ret == LY1211_EXTREG_PHY_MODE_SGMII_PHY_TO_RGMII_MAC || 
        ret == LY1211_EXTREG_PHY_MODE_SGMII_MAC_TO_RGMII_PHY) {
        mode = LYPHY_PORT_TYPE_FIBER;
    } else {
        mode = LYPHY_PORT_TYPE_COMBO;
    }

    return mode;
}

static int ly1121_led_init(struct phy_device *phydev)
{
    int ret;

    ret = linkyum_phy_ext_write(phydev, LY1211_EXTREG_LED0, 0x00);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1211_EXTREG_LED1, 0x2F);
    if (ret < 0)
        return ret;
        
    return linkyum_phy_ext_write(phydev, LY1211_EXTREG_LED2, 0x40);
}

static int ly1241_led_init(struct phy_device *phydev)
{
    int ret;
    // set led put low level
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LEDCTRL, 0x04);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_read(phydev, LY1241_EXTREG_LED0_1);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_read(phydev, LY1241_EXTREG_LED0_2);
    if (ret < 0)
        return ret;


    // set led 0 1
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED0_1, 0x00);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED0_2, 0x08);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED1_1, 0xF0);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED1_2, 0x0E);
    if (ret < 0)
        return ret;

    // set led 2 3
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED2_1, 0x00);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED2_2, 0x18);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED3_1, 0xF0);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED3_2, 0x1E);
    if (ret < 0)
        return ret;

    // set led 4    
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED4_1, 0x00);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED4_2, 0x28);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED5_1, 0xFE);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED5_2, 0x2E);
    if (ret < 0)
        return ret;

    // set led 6
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED6_2, 0x00);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED6_2, 0x38);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED7_1, 0xF0);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY1241_EXTREG_LED7_2, 0x3E);
    if (ret < 0)
        return ret;

    return ret;
}


static int lyphy_restart_aneg(struct phy_device *phydev)
{
    int ret, ctl;

    ctl = lyphy_page_read(phydev, LYPHY_REG_FIBER_SPACE, MII_BMCR);
    if (ctl < 0)
        return ctl;
    ctl |= BMCR_ANENABLE;
    ret = lyphy_page_write(phydev, LYPHY_REG_FIBER_SPACE, MII_BMCR, ctl);
    if (ret < 0)
        return ret;

    return 0;
}

int ly1211_config_aneg(struct phy_device *phydev)
{
    int ret, phymode, oldpage = 0;

    phymode = LYPHY_MODE_CURR;

    if (phymode == LYPHY_PORT_TYPE_UTP || phymode == LYPHY_PORT_TYPE_COMBO) {
        oldpage = linkyum_phy_get_reg_page(phydev);
        if (oldpage < 0)
            return oldpage;
        ret = linkyum_phy_select_reg_page(phydev, LYPHY_REG_UTP_SPACE);
        if (ret < 0)
            return ret;
        ret = genphy_config_aneg(phydev);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_select_reg_page(phydev, oldpage);
        if (ret < 0)
            return ret;
    }

    if (phymode == LYPHY_PORT_TYPE_FIBER || phymode == LYPHY_PORT_TYPE_COMBO) {
        oldpage = linkyum_phy_get_reg_page(phydev);
        if (oldpage < 0)
            return oldpage;
        ret = linkyum_phy_select_reg_page(phydev, LYPHY_REG_FIBER_SPACE);
        if (ret < 0)
            return ret;
        if (AUTONEG_ENABLE != phydev->autoneg) 
            return genphy_setup_forced(phydev);
        ret = lyphy_restart_aneg(phydev);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_select_reg_page(phydev, oldpage);
        if (ret < 0)
            return ret;
    }
    return 0;
}

#if (KERNEL_VERSION(3, 14, 79) < LINUX_VERSION_CODE)
int ly1211_aneg_done(struct phy_device *phydev)
{
	int val = 0;

    val = phy_read(phydev, 0x16);

    if (val == LYPHY_REG_FIBER_SPACE_SETADDR) {
        val = phy_read(phydev, 0x1);
        val = phy_read(phydev, 0x1);
        return (val < 0) ? val : (val & BMSR_LSTATUS);
    }
	
    return genphy_aneg_done(phydev);
}
#endif

#if (LINKYUM_PHY_WOL_FEATURE_ENABLE)
static void linkyum_get_wol(struct phy_device *phydev, struct ethtool_wolinfo *wol)
{
    int val = 0;
    wol->supported = WAKE_MAGIC;
    wol->wolopts = 0;

    val = linkyum_phy_ext_read(phydev, LINKYUM_WOL_CFG_REG1);
    if (val < 0)
        return;

    if (val & LINKYUM_WOL_EN)
        wol->wolopts |= WAKE_MAGIC;

    return;
}

static int linkyum_wol_en_cfg(struct phy_device *phydev, linkyum_wol_cfg_t wol_cfg)
{
    int ret, val0,val1;

    val0 = linkyum_phy_ext_read(phydev, LINKYUM_WOL_CFG_REG0);
    if (val0 < 0)
        return val0;
    val1 = linkyum_phy_ext_read(phydev, LINKYUM_WOL_CFG_REG1);
    if (val1 < 0)
        return val1;
    if (wol_cfg.wolen) {
        val1 |= LINKYUM_WOL_EN;
        if (wol_cfg.type == LYPHY_WOL_TYPE_LEVEL) {
            val0 |= LINKYUM_WOL_TYPE;
        } else if (wol_cfg.type == LYPHY_WOL_TYPE_PULSE) {
            ret = linkyum_phy_ext_write(phydev, LINKYUM_PHY_WOL_PULSE_MODE_SET, 0x04);//set int pin pulse
            if (ret < 0)
                return ret;
            val0 &= ~LINKYUM_WOL_TYPE;
            if (wol_cfg.width == LYPHY_WOL_WIDTH_84MS) {
                val0 &= ~LINKYUM_WOL_WIDTH1;
                val0 &= ~LINKYUM_WOL_WIDTH2;
            } else if (wol_cfg.width == LYPHY_WOL_WIDTH_168MS) {
                val0 |= LINKYUM_WOL_WIDTH1;
                val0 &= ~LINKYUM_WOL_WIDTH2;
            } else if (wol_cfg.width == LYPHY_WOL_WIDTH_336MS) {
                val0 &= ~LINKYUM_WOL_WIDTH1;
                val0 |= LINKYUM_WOL_WIDTH2;
            } else if (wol_cfg.width == LYPHY_WOL_WIDTH_672MS) {
                val0 |= LINKYUM_WOL_WIDTH1;
                val0 |= LINKYUM_WOL_WIDTH2;
            }
        }
        if (wol_cfg.secure == LYPHY_GLB_ENABLE)
            val1 |= LINKYUM_WOL_SECURE_CHECK;
        else 
            val1 &= ~LINKYUM_WOL_SECURE_CHECK;
        if (wol_cfg.checkcrc == LYPHY_GLB_ENABLE)
            val0 |= LINKYUM_WOL_CRC_CHECK;
        else 
            val0 &= ~LINKYUM_WOL_CRC_CHECK;
        if (wol_cfg.checkdst == LYPHY_GLB_ENABLE)
            val0 |= LINKYUM_WOL_DESTADDR_CHECK;
        else 
            val0 &= ~LINKYUM_WOL_DESTADDR_CHECK;
    } else {
        val1 &= ~LINKYUM_WOL_EN;
    }

    ret = linkyum_phy_ext_write(phydev, LINKYUM_WOL_CFG_REG0, val0);
    if (ret < 0)
        return ret;
    ret = linkyum_phy_ext_write(phydev, LINKYUM_WOL_CFG_REG1, val1);
    if (ret < 0)
        return ret;
    return 0;
}

static int linkyum_set_wol(struct phy_device *phydev, struct ethtool_wolinfo *wol)
{
    int ret, val, i, phymode;
    linkyum_wol_cfg_t wol_cfg;

    phymode = LYPHY_MODE_CURR;
    memset(&wol_cfg,0,sizeof(linkyum_wol_cfg_t));

    if (wol->wolopts & WAKE_MAGIC) {
        if (phymode == LYPHY_PORT_TYPE_UTP || phymode == LYPHY_PORT_TYPE_COMBO) {
        /* Enable the WOL interrupt */
        val = lyphy_page_read(phydev, LYPHY_REG_UTP_SPACE, LINKYUM_INTR_REG);
        val |= LINKYUM_WOL_INTR_EN;
        ret = lyphy_page_write(phydev, LYPHY_REG_UTP_SPACE, LINKYUM_INTR_REG, val);
        if (ret < 0)
            return ret;
        }
        if (phymode == LYPHY_PORT_TYPE_FIBER || phymode == LYPHY_PORT_TYPE_COMBO) {
            /* Enable the WOL interrupt */
            val = lyphy_page_read(phydev, LYPHY_REG_FIBER_SPACE, LINKYUM_INTR_REG);
            val |= LINKYUM_WOL_INTR_EN;
            ret = lyphy_page_write(phydev, LYPHY_REG_FIBER_SPACE, LINKYUM_INTR_REG, val);
            if (ret < 0)
                return ret;
        }
        /* Set the WOL config */
        wol_cfg.wolen = LYPHY_GLB_ENABLE;
        wol_cfg.type  = LYPHY_WOL_TYPE_PULSE;
        wol_cfg.width = LYPHY_WOL_WIDTH_672MS;
        wol_cfg.checkdst  = LYPHY_GLB_ENABLE;
        wol_cfg.checkcrc = LYPHY_GLB_ENABLE;
        ret = linkyum_wol_en_cfg(phydev, wol_cfg);
        if (ret < 0)
            return ret;

        /* Store the device address for the magic packet */
        for(i = 0; i < 6; ++i) {
            ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_MAC_ADDR - i,
                ((phydev->attached_dev->dev_addr[i])));
            if (ret < 0)
                return ret;
        }
#if LINKYUM_PHY_WOL_PASSWD_ENABLE
        /* Set passwd for the magic packet */
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR, LINKYUM_MAGIC_PACKET_PASSWD1);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR - 1, LINKYUM_MAGIC_PACKET_PASSWD2);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR - 2, LINKYUM_MAGIC_PACKET_PASSWD3);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR - 3, LINKYUM_MAGIC_PACKET_PASSWD4);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR - 4, LINKYUM_MAGIC_PACKET_PASSWD5);
        if (ret < 0)
            return ret;
        ret = linkyum_phy_ext_write(phydev, LINKYUM_MAGIC_PACKET_PASSWD_ADDR - 5, LINKYUM_MAGIC_PACKET_PASSWD6);
        if (ret < 0)
            return ret;
#endif
    } else {
        wol_cfg.wolen = LYPHY_GLB_DISABLE;
        wol_cfg.type  = LYPHY_WOL_TYPE_EXT;
        wol_cfg.width = LYPHY_WOL_WIDTH_EXT;
        wol_cfg.checkdst  = LYPHY_GLB_DISABLE;
        wol_cfg.checkcrc  = LYPHY_GLB_DISABLE;
        ret = linkyum_wol_en_cfg(phydev, wol_cfg);
        if (ret < 0)
            return ret;
    }

    if (val == LY1211_EXTREG_PHY_MODE_UTP_TO_SGMII) {
        val = lyphy_page_read(phydev, LYPHY_REG_UTP_SPACE, MII_BMCR);
        val |= LINKYUM_WOL_RESTARTANEG;
        ret = lyphy_page_write(phydev, LYPHY_REG_UTP_SPACE, MII_BMCR, val);
        if (ret < 0)
            return ret;
    }

    return 0;
}
#endif
static int ly1211_rxc_init(struct phy_device *phydev)
{
    int ret;

    ret = (linkyum_phy_ext_read(phydev, LY1211_EXTREG_GET_PORT_PHY_MODE) & 
        LY1211_EXTREG_PHY_MODE_MASK);
    if (ret < 0)
        return ret;
        
    if ((ret == LY1211_EXTREG_PHY_MODE_UTP_TO_SGMII) || 
        (ret == LY1211_EXTREG_PHY_MODE_UTP_TO_FIBER_AUTO) ||
        (ret == LY1211_EXTREG_PHY_MODE_UTP_TO_FIBER_FORCE))
        return 0;

    // Init rxc and enable rxc
    if (ret == LY1211_EXTREG_PHY_MODE_UTP_TO_RGMII) {   
        ret = phy_read(phydev, 0x11);
        if ((ret & 0x4) == 0x0) {
            ret = linkyum_phy_ext_write(phydev,0x1E0C, 0x17);
            if (ret < 0)
                return ret;
            ret = linkyum_phy_ext_write(phydev,0x1E58, 0x00);
            if (ret < 0)
                return ret;
	    }
    }


#if LINKYUM_PHY_RXC_DELAY_SET_ENABLE
    // Init rxc delay
    ret = linkyum_phy_ext_write(phydev,0x0282, LINKYUM_PHY_RXC_DELAY_VAL);
    if (ret < 0)
        return ret;
#endif

    return ret;
}
static int ly1211_config_opt(struct phy_device *phydev)
{
    int ret;
    //100M utp optimise
    ret = linkyum_phy_ext_write(phydev, 0x0149, 0x84);
    if (ret < 0)
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0x014A, 0x86);
    if (ret < 0)
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0x023C, 0x81);
    if (ret < 0)
        return ret;

    //1000M utp optimise
    ret = linkyum_phy_ext_write(phydev, 0x0184, 0x85);
    if (ret < 0)
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0x0185, 0x86);
    if (ret < 0)
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0x0186, 0x85);
    if (ret < 0)
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0x0187, 0x86);
    if (ret < 0)
        return ret;
    return ret;
}

#if LINKYUM_PHY_CLK_OUT_125M_ENABLE
static int ly1211_clkout_init(struct phy_device *phydev)
{
    int ret;
    
    ret = linkyum_phy_ext_write(phydev, 0x0272 , 0x49);
    if (ret < 0)
        return ret;

    return ret;
}
#endif

#if LINKYUM_PHY_MODE_SET_ENABLE
//set mode
static int phy_mode_set(struct phy_device *phydev, u16 phyMode)
{
    int ret, num = 0;

    ret = linkyum_phy_ext_read(phydev, 0xC417);
    if (ret < 0)
        return ret;

    ret = (ret & 0xF0) | (0x8 | phyMode);

    ret = linkyum_phy_ext_write(phydev, 0xC417, ret);
    if (ret < 0)
        return ret;

    while ((linkyum_phy_ext_read(phydev, 0xC415) & 0x07) != phyMode) {
        msleep(10);
        if(++num == 5) {
            printk("Phy Mode Set Time Out!\r\n");
            break;
        }
    }

    while (linkyum_phy_ext_read(phydev, 0xC413) != 0) {
        msleep(10);
        if(++num == 10) {
            printk("Phy Mode Set Time Out!\r\n");
            break;
        }
    }       

    return 0;
}
#endif

#if (KERNEL_VERSION(3, 16, 0) > LINUX_VERSION_CODE)
static int genphy_config_init(struct phy_device *phydev)
{
    int val;
    u32 features;

    features = (SUPPORTED_TP | SUPPORTED_MII
            | SUPPORTED_AUI | SUPPORTED_FIBRE |
            SUPPORTED_BNC | SUPPORTED_Pause | SUPPORTED_Asym_Pause);

    /* Do we support autonegotiation? */
    val = phy_read(phydev, MII_BMSR);
    if (val < 0)
        return val;

    if (val & BMSR_ANEGCAPABLE)
        features |= SUPPORTED_Autoneg;

    if (val & BMSR_100FULL)
        features |= SUPPORTED_100baseT_Full;
    if (val & BMSR_100HALF)
        features |= SUPPORTED_100baseT_Half;
    if (val & BMSR_10FULL)
        features |= SUPPORTED_10baseT_Full;
    if (val & BMSR_10HALF)
        features |= SUPPORTED_10baseT_Half;

    if (val & BMSR_ESTATEN) {
        val = phy_read(phydev, MII_ESTATUS);
        if (val < 0)
            return val;

        if (val & ESTATUS_1000_TFULL)
            features |= SUPPORTED_1000baseT_Full;
        if (val & ESTATUS_1000_THALF)
            features |= SUPPORTED_1000baseT_Half;
    }

    phydev->supported &= features;
    phydev->advertising &= features;

    return 0;
}
#endif

int ly1241_power_updown_init(struct phy_device *phydev)
{
    int ret = 0, num = 0;

    ret = linkyum_phy_ext_read(phydev, 0xC419);//version
    if (ret < 0 || ret > 0x02) 
        return ret;
        
    ret = linkyum_phy_ext_write(phydev, 0xC464, 0x01);//powerdown
    if (ret < 0) 
        return ret;
    
    while (!(linkyum_phy_ext_read(phydev, 0xC465))) {
        msleep(10);
        if(++num == 5) {
            printk("Phy powerdown Set Time Out!\r\n");
            break;
        }
    }

    ret = linkyum_phy_ext_write(phydev, 0x060E, 0x00);
    if (ret < 0) 
        return ret;

    ret = linkyum_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = linkyum_phy_ext_write(phydev, 0x20A4, ret | 0x04);
    if (ret < 0) 
        return ret;

    ret = linkyum_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = linkyum_phy_ext_write(phydev, 0x20A4, ret & ~(0x04));
    if (ret < 0) 
        return ret;
        
    ret = linkyum_phy_ext_write(phydev, 0x060E, 0x01);
    if (ret < 0) 
        return ret;

    ret = linkyum_phy_ext_write(phydev, 0xC464, 0x00);//powerup
    if (ret < 0) 
        return ret;

    msleep(10);

    return ret;
}

#if LINKYUM_PHY_LY1241V2_CFG_ENABLE
static int ly1241phy_load_cfg(struct phy_device *phydev)
{
    int i, ver, ret;

    // get version
    ret = linkyum_phy_ext_read(phydev, 0xC419);
    if (ret < 0) 
        return ret;
    ver = ret;

    // disable startup patch and restart
    ret = linkyum_phy_ext_write(phydev, LY_CFG_INIT, 0x85);
    if (ret < 0) 
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY_CFG_WAIT, 0x01);
    if (ret < 0) 
        return ret;
    ret = linkyum_phy_ext_write(phydev, LY_CFG_EPHY_INIT, 0x85);
    if (ret < 0) 
        return ret;

    // init exp write, addr auto inc for fast load cfg
    ret = phy_write(phydev, 0x16, 0x01);
    if (ret < 0) 
        return ret;

    ret = phy_write(phydev, 0x0E, LY_CFG_ADDR);
    if (ret < 0) 
        return ret;

#if LINKYUM_PHY_LY1241V2_CFG_ENABLE
    for(i = 0; i < sizeof(LINKYUM_LY1241V2_CFG) / sizeof(LINKYUM_LY1241V2_CFG[0]); i++) {
        ret = phy_write(phydev, 0x0D, LINKYUM_LY1241V2_CFG[i]);
        if (ret < 0) 
            return ret;
    }
#endif

    ret = phy_write(phydev, 0x16, 0x00);
    if (ret < 0) 
        return ret;

    ret = linkyum_phy_ext_write(phydev, LY_CFG_WAIT, 0x00);
    if (ret < 0) 
        return ret;
    
    i = 0;
    
    // check            
    while (!((linkyum_phy_ext_read(phydev, LY_CFG_ENABLE) == 0x85) &&
        (linkyum_phy_ext_read(phydev, LY_CFG_ENABLE_ACK) == 0x85))) {
        msleep(10);
        if(++i == 5) {
            printk("Phy LY1241 CFG Load Time Out!\r\n");
            break;
        }
    }

    printk("Phy LY1241 CFG VERSION : 0x%x\r\n", linkyum_phy_ext_read(phydev, 0xC461));

    return 0;
}
#endif

int ly1241_config_init(struct phy_device *phydev)
{
    int ret;
    
#if LINKYUM_PHY_LY1241V2_CFG_ENABLE
    ret = ly1241phy_load_cfg(phydev);
    if (ret < 0)
        return ret;
#endif

#if (KERNEL_VERSION(5, 4, 0) > LINUX_VERSION_CODE)
        ret = genphy_config_init(phydev);
#else
        ret = genphy_read_abilities(phydev);
#endif
    if (ret < 0)
        return ret;

    
#if (KERNEL_VERSION(5, 0, 0) > LINUX_VERSION_CODE)
        phydev->supported |= SUPPORTED_1000baseT_Full;
        phydev->advertising |= SUPPORTED_1000baseT_Full;
#else
        linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT,
                phydev->supported, ESTATUS_1000_TFULL);
        linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT,
                phydev->advertising, ESTATUS_1000_TFULL);
#endif

#if LINKYUM_PHY_LINK_OPT_ENABLE
    ret = ly1241_power_updown_init(phydev);
    if (ret < 0)
        return ret;
#endif

    return ly1241_led_init(phydev);
}

int ly1210_power_updown_init(struct phy_device *phydev)
{
    int ret = 0, num = 0;

    ret = ly1211_phy_ext_read(phydev, 0xC419);//version
    if (ret < 0 || ret > 0x02) 
        return ret;

    ret = ly1211_phy_ext_write(phydev, 0xC464, 0x01);//powerdown
    if (ret < 0) 
        return ret;
    
    while (!(ly1211_phy_ext_read(phydev, 0xC465))) {
        msleep(10);
        if(++num == 5) {
            printk("Phy powerdown Set Time Out!\r\n");
            break;
        }
    }

    ret = ly1211_phy_ext_write(phydev, 0x060E, 0x00);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, 0x20A4, ret | 0x20);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, 0x20A4, ret & ~(0x20));
    if (ret < 0) 
        return ret;
        
    ret = ly1211_phy_ext_write(phydev, 0x060E, 0x01);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_write(phydev, 0xC464, 0x00);//powerup
    if (ret < 0) 
        return ret;

    msleep(10);

    return ret;
}


int ly1210_config_init(struct phy_device *phydev)
{
    int ret = 0;
#if LINKYUM_PHY_LINK_OPT_ENABLE
    ret = ly1210_power_updown_init(phydev);
    if (ret < 0)
        return ret;
#endif

    return ret;
}


int ly1211_power_updown_init(struct phy_device *phydev)
{
    int ret = 0, num = 0, temp = 0;

    ret = ly1211_phy_ext_read(phydev, 0xC419);//version
    if (ret < 0 || ret > 0x02) 
        return ret;
    
    ret = phy_read(phydev, 0x1C);
    if (ret < 0) 
        return ret;
    temp = ret;

    ret = phy_write(phydev, 0x1C, 0x4000);//powerdown
    if (ret < 0) 
        return ret;

    while (ly1211_phy_ext_read(phydev, 0x40) || ly1211_phy_ext_read(phydev, 0x256)) {
        msleep(10);
        if(++num == 5) {
            printk("Phy powerdown Set Time Out!\r\n");
            break;
        }
    }

    ret = ly1211_phy_ext_write(phydev, 0x060E, 0x00);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, 0x20A4, ret | 0x04);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_read(phydev, 0x20A4);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, 0x20A4, ret & ~(0x04));
    if (ret < 0) 
        return ret;
        
    ret = ly1211_phy_ext_write(phydev, 0x060E, 0x01);
    if (ret < 0) 
        return ret;

    ret = phy_write(phydev, 0x1C, temp);//powerup
    if (ret < 0) 
        return ret;

    while (ly1211_phy_ext_read(phydev, 0x40) || ly1211_phy_ext_read(phydev, 0x256)) {
        msleep(10);
        if(++num == 5) {
            printk("Phy powerup Set Time Out!\r\n");
            break;
        }
    }

    return ret;
}

#if LINKYUM_PHY_LY1211V1_CFG_ENABLE || LINKYUM_PHY_LY1211V2_CFG_ENABLE
static int ly1211phy_load_cfg(struct phy_device *phydev)
{
    int i, ver, ret;

    // get version
    ret = ly1211_phy_ext_read(phydev, 0xC419);
    if (ret < 0) 
        return ret;
    ver = ret;

    // disable startup patch and restart
    ret = ly1211_phy_ext_write(phydev, LY_CFG_INIT, 0x85);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, LY_CFG_WAIT, 0x01);
    if (ret < 0) 
        return ret;
    ret = ly1211_phy_ext_write(phydev, LY_CFG_EPHY_INIT, 0x85);
    if (ret < 0) 
        return ret;

    // init exp write, addr auto inc for fast load cfg
    ret = phy_write(phydev, 0x16, 0x01);
    if (ret < 0) 
        return ret;

    ret = phy_write(phydev, 0x0E, LY_CFG_ADDR);
    if (ret < 0) 
        return ret;

#if LINKYUM_PHY_LY1211V1_CFG_ENABLE
    if (ver ==  0x01) {
        for(i = 0; i < sizeof(LINKYUM_LY1211V1_CFG) / sizeof(LINKYUM_LY1211V1_CFG[0]); i++) {
            ret = phy_write(phydev, 0x0D, LINKYUM_LY1211V1_CFG[i]);
            if (ret < 0) 
                return ret;
        }
    } 
#endif

#if LINKYUM_PHY_LY1211V2_CFG_ENABLE
    if (ver == 0x02) {
        for(i = 0; i < sizeof(LINKYUM_LY1211V2_CFG) / sizeof(LINKYUM_LY1211V2_CFG[0]); i++) {
            ret = phy_write(phydev, 0x0D, LINKYUM_LY1211V2_CFG[i]);
            if (ret < 0) 
                return ret;
        }
    }
#endif

    ret = phy_write(phydev, 0x16, 0x00);
    if (ret < 0) 
        return ret;

    ret = ly1211_phy_ext_write(phydev, LY_CFG_WAIT, 0x00);
    if (ret < 0) 
        return ret;
    
    i = 0;
    
    // check            
    while (!((linkyum_phy_ext_read(phydev, LY_CFG_ENABLE) == 0x85) &&
        (linkyum_phy_ext_read(phydev, LY_CFG_ENABLE_ACK) == 0x85))) {
        msleep(10);
        if(++i == 5) {
            printk("Phy LY1211 CFG Load Time Out!\r\n");
            break;
        }
    }

    printk("Phy LY1211 CFG VERSION : 0x%x\r\n", linkyum_phy_ext_read(phydev, 0xC461));

    return 0;
}
#endif

int ly1211_config_init(struct phy_device *phydev)
{
    int ret, phymode;

#if LINKYUM_PHY_LY1211V1_CFG_ENABLE || LINKYUM_PHY_LY1211V2_CFG_ENABLE
    ret = ly1211phy_load_cfg(phydev);
    if (ret < 0)
        return ret;
#endif

#if LINKYUM_PHY_WOL_FEATURE_ENABLE
    struct ethtool_wolinfo wol;
#endif

#if LINKYUM_PHY_MODE_SET_ENABLE
    ret = phy_mode_set(phydev, 0x0);
    if (ret < 0) 
        return ret;
#endif
    phymode = LYPHY_MODE_CURR;

    if (phymode == LYPHY_PORT_TYPE_UTP || phymode == LYPHY_PORT_TYPE_COMBO) {
        linkyum_phy_select_reg_page(phydev, LYPHY_REG_UTP_SPACE);
#if (KERNEL_VERSION(5, 4, 0) > LINUX_VERSION_CODE)
        ret = genphy_config_init(phydev);
#else
        ret = genphy_read_abilities(phydev);
#endif
        if (ret < 0)
            return ret;
    } else {
        linkyum_phy_select_reg_page(phydev, LYPHY_REG_FIBER_SPACE);
#if (KERNEL_VERSION(5, 4, 0) > LINUX_VERSION_CODE)
        ret = genphy_config_init(phydev);
        if (ret < 0)
            return ret;
#else 
        ret = genphy_read_abilities(phydev);
        if (ret < 0)
            return ret;
#endif

#if (KERNEL_VERSION(5, 0, 0) > LINUX_VERSION_CODE)
        phydev->supported |= SUPPORTED_1000baseT_Full;
        phydev->advertising |= SUPPORTED_1000baseT_Full;
#else
        linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT,
                phydev->supported, ESTATUS_1000_TFULL);
        linkmode_mod_bit(ETHTOOL_LINK_MODE_1000baseT_Full_BIT,
                phydev->advertising, ESTATUS_1000_TFULL);
#endif
    }

#if LINKYUM_PHY_LINK_OPT_ENABLE
    ret = ly1211_power_updown_init(phydev);
    if (ret < 0)
        return ret;
#endif

    ret = ly1211_rxc_init(phydev);
    if (ret < 0)
        return ret;

    ret = ly1211_config_opt(phydev);
    if (ret < 0)
        return ret;

#if LINKYUM_PHY_CLK_OUT_125M_ENABLE
    ret = ly1211_clkout_init(phydev);
    if (ret < 0)
        return ret;
#endif

#if LINKYUM_PHY_WOL_FEATURE_ENABLE
    wol.wolopts = 0;
    wol.supported = WAKE_MAGIC;
    wol.wolopts |= WAKE_MAGIC;
    linkyum_set_wol(phydev, &wol);
#endif

    return ly1121_led_init(phydev);
}

static int ly1211_update_link(struct phy_device *phydev)
{
    int ret, val, phymode;

    phymode = LYPHY_MODE_CURR;

    if (phymode == LYPHY_PORT_TYPE_UTP || phymode == LYPHY_PORT_TYPE_COMBO) {
        /* Do a fake read */
        ret = lyphy_page_read(phydev, LYPHY_REG_UTP_SPACE, MII_BMSR);
        if (ret < 0)
            return ret;

        /* Read link and autonegotiation status */
        ret = lyphy_page_read(phydev, LYPHY_REG_UTP_SPACE, MII_BMSR);
        if (ret < 0)
            return ret;
        if ((ret & BMSR_LSTATUS) == 0) {
            phydev->link = LYPHY_LINK_DOWN;
        } else {
            phydev->link = LYPHY_LINK_UP;

            val = linkyum_phy_ext_read(phydev, LY1211_EXTREG_GET_PORT_PHY_MODE) & LY1211_EXTREG_PHY_MODE_MASK;
            if (val < 0)
                return val;
            if (val == LY1211_EXTREG_PHY_MODE_UTP_OR_FIBER_TO_RGMII) {
                linkyum_phy_select_reg_page(phydev, LYPHY_REG_UTP_SPACE);
            }
            return LYPHY_REG_UTP_SPACE;
        }
    }

    if (phymode == LYPHY_PORT_TYPE_FIBER || phymode == LYPHY_PORT_TYPE_COMBO) {
        /* Do a fake read */
        ret = lyphy_page_read(phydev, LYPHY_REG_FIBER_SPACE, MII_BMSR);
        if (ret < 0)
            return ret;

        /* Read link and autonegotiation status */
        ret = lyphy_page_read(phydev, LYPHY_REG_FIBER_SPACE, MII_BMSR);
        if (ret < 0)
            return ret;

        if ((ret & BMSR_LSTATUS) == 0) {
            phydev->link = LYPHY_LINK_DOWN;
            return LYPHY_REG_UTP_SPACE;
        } else {
            val = linkyum_phy_ext_read(phydev, LY1211_EXTREG_GET_PORT_PHY_MODE) & LY1211_EXTREG_PHY_MODE_MASK;
            if (val < 0)
                return val;
            if (val != LY1211_EXTREG_PHY_MODE_SGMII_MAC_TO_RGMII_PHY) {
                if (val == LY1211_EXTREG_PHY_MODE_UTP_OR_FIBER_TO_RGMII) {
                    linkyum_phy_select_reg_page(phydev, LYPHY_REG_FIBER_SPACE);
                }
                phydev->link = LYPHY_LINK_UP;
            } else {
                ret = lyphy_page_read(phydev, LYPHY_REG_FIBER_SPACE, 0x1C);
                if ((ret & 0x8000) == 0) {
                    phydev->link = LYPHY_LINK_DOWN;
                } else {
                    phydev->link = LYPHY_LINK_UP;
                }
            }
            return LYPHY_REG_FIBER_SPACE;
        }
    }
    return LYPHY_REG_UTP_SPACE;
}

static int ly1211_read_status(struct phy_device *phydev)
{
    int val, ret, lpa, page;
    
    /* Update the link, but return if there was an error */
    ret = ly1211_update_link(phydev);
    if (ret < 0)
        return ret;
    page = ret;

    phydev->speed = SPEED_10;
    phydev->duplex = DUPLEX_HALF;
    phydev->pause = 0;
    phydev->asym_pause = 0;

    val = lyphy_page_read(phydev, page, LINKYUM_SPEC_REG);
    if (val < 0)
        return val;

    lpa = lyphy_page_read(phydev, page, MII_LPA);
    if (lpa < 0)
        return lpa;

    if (val & 0x02) 
        phydev->duplex = DUPLEX_FULL;
    if ((val & 0x18) == 0x10) 
        phydev->speed = SPEED_1000;
    if ((val & 0x18) == 0x08) 
        phydev->speed = SPEED_100;
    if (phydev->duplex == DUPLEX_FULL) {
        if(page == LYPHY_REG_UTP_SPACE) {
            phydev->pause = lpa & UTP_REG_PAUSE_CAP ? 1 : 0;
            phydev->asym_pause = lpa & UTP_REG_PAUSE_ASYM ? 1 : 0;
        } else {
            phydev->pause = lpa & FIBER_REG_PAUSE_CAP ? 1 : 0;
            phydev->asym_pause = lpa & FIBER_REG_PAUSE_ASYM ? 1 : 0;
        }
    } 
    return 0;
}


static int ly1241_update_link(struct phy_device *phydev)
{
    int ret;

    /* Do a fake read */
    ret = ly1241_phy_read(phydev, MII_BMSR);
    if (ret < 0)
        return ret;

    /* Read link and autonegotiation status */
    ret = ly1241_phy_read(phydev, MII_BMSR);
    if (ret < 0)
        return ret;

    if ((ret & BMSR_LSTATUS) == 0)
        phydev->link = LYPHY_LINK_DOWN;
    else 
        phydev->link = LYPHY_LINK_UP;
    
    return 0;
}

static int ly1241_read_status(struct phy_device *phydev)
{
    int val, ret, lpa;
    
    /* Update the link, but return if there was an error */
    ret = ly1241_update_link(phydev);
    if (ret < 0)
        return ret;

    phydev->speed = SPEED_10;
    phydev->duplex = DUPLEX_HALF;
    phydev->pause = 0;
    phydev->asym_pause = 0;

    val = ly1241_phy_read(phydev, LINKYUM_SPEC_REG);
    if (val < 0)
        return val;

    lpa = ly1241_phy_read(phydev, MII_LPA);
    if (lpa < 0)
        return lpa;

    if (val & 0x02) 
        phydev->duplex = DUPLEX_FULL;
    if ((val & 0x18) == 0x10) 
        phydev->speed = SPEED_1000;
    if ((val & 0x18) == 0x08) 
        phydev->speed = SPEED_100;
    if (phydev->duplex == DUPLEX_FULL) {
        phydev->pause = lpa & UTP_REG_PAUSE_CAP ? 1 : 0;
        phydev->asym_pause = lpa & UTP_REG_PAUSE_ASYM ? 1 : 0;
    } 
    return 0;
}

static int ly1210_read_status(struct phy_device *phydev)
{
    int val, ret, lpa;
    
    /* Update the link, but return if there was an error */
    ret = ly1241_update_link(phydev);
    if (ret < 0)
        return ret;

    phydev->speed = SPEED_10;
    phydev->duplex = DUPLEX_HALF;
    phydev->pause = 0;
    phydev->asym_pause = 0;

    val = ly1241_phy_read(phydev, LINKYUM_SPEC_REG);
    if (val < 0)
        return val;

    lpa = ly1241_phy_read(phydev, MII_LPA);
    if (lpa < 0)
        return lpa;

    if (val & 0x02) 
        phydev->duplex = DUPLEX_FULL;
    // if ((val & 0x18) == 0x10) 
    //     phydev->speed = SPEED_1000;
    if ((val & 0x18) == 0x08) 
        phydev->speed = SPEED_100;
    if (phydev->duplex == DUPLEX_FULL) {
        phydev->pause = lpa & UTP_REG_PAUSE_CAP ? 1 : 0;
        phydev->asym_pause = lpa & UTP_REG_PAUSE_ASYM ? 1 : 0;
    } 
    return 0;
}

static struct phy_driver ly_phy_drivers[] = {
    {
        .phy_id             = LY1210_PHY_ID,
        .phy_id_mask        = LINKYUM_PHY_ID_MASK,
        .name               = "LY1210A 100M Ethernet",
        .features           = PHY_BASIC_FEATURES,
        .flags              = PHY_POLL,
        .config_init        = ly1210_config_init,
        .read_status        = ly1210_read_status,
#if (KERNEL_VERSION(4, 12, 0) <= LINUX_VERSION_CODE)
        .write_mmd          = genphy_write_mmd_unsupported,
        .read_mmd           = genphy_read_mmd_unsupported,
#endif
    },

    {
        .phy_id             = LY1211_PHY_ID,
        .phy_id_mask        = LINKYUM_PHY_ID_MASK,
        .name               = "LY1211A_LY1211S Gigabit Ethernet",
        .features           = PHY_GBIT_FEATURES,
        .flags              = PHY_POLL,
        .config_init        = ly1211_config_init,
        .config_aneg        = ly1211_config_aneg,
#if (KERNEL_VERSION(3, 14, 79) < LINUX_VERSION_CODE)
        .aneg_done          = ly1211_aneg_done,
#endif
        .read_status        = ly1211_read_status,
#if (KERNEL_VERSION(4, 12, 0) <= LINUX_VERSION_CODE)
        .write_mmd          = genphy_write_mmd_unsupported,
        .read_mmd           = genphy_read_mmd_unsupported,
#endif
        .suspend            = genphy_suspend,
        .resume             = genphy_resume,
#if LINKYUM_PHY_WOL_FEATURE_ENABLE
        .get_wol            = &linkyum_get_wol,
        .set_wol            = &linkyum_set_wol,
#endif
    },
    
    {
        .phy_id             = LY1241_PHY_ID,
        .phy_id_mask        = LINKYUM_PHY_ID_MASK,
        .name               = "LY1241A_LY1241B Gigabit Ethernet",
        .features           = PHY_GBIT_FEATURES,
        .flags              = PHY_POLL,
        .config_init        = ly1241_config_init,
        .config_aneg        = genphy_config_aneg,
        .read_status        = ly1241_read_status,
#if (KERNEL_VERSION(4, 12, 0) <= LINUX_VERSION_CODE)
        .write_mmd          = genphy_write_mmd_unsupported,
        .read_mmd           = genphy_read_mmd_unsupported,
#endif
        .suspend            = genphy_suspend,
        .resume             = genphy_resume,
    },
};

#if (KERNEL_VERSION(4, 0, 0) > LINUX_VERSION_CODE)
static int ly_phy_drivers_register(struct phy_driver *phy_drvs, int size)
{
    int i, j;
    int ret;

    for (i = 0; i < size; i++) {
        ret = phy_driver_register(&phy_drvs[i]);
        if (ret)
            goto err;
    }

    return 0;

err:
        for (j = 0; j < i; j++)
            phy_driver_unregister(&phy_drvs[j]);

    return ret;
}

static void ly_phy_drivers_unregister(struct phy_driver *phy_drvs, int size)
{
    int i;

    for (i = 0; i < size; i++)
        phy_driver_unregister(&phy_drvs[i]);
}

static int __init ly_phy_init(void)
{
    return ly_phy_drivers_register(ly_phy_drivers, ARRAY_SIZE(ly_phy_drivers));
}

static void __exit ly_phy_exit(void)
{
    ly_phy_drivers_unregister(ly_phy_drivers, ARRAY_SIZE(ly_phy_drivers));
}

module_init(ly_phy_init);
module_exit(ly_phy_exit);
#else
/* for linux 4.x */
module_phy_driver(ly_phy_drivers);
#endif

static struct mdio_device_id __maybe_unused linkyum_phy_tbl[] = {
    { LY1210_PHY_ID, LINKYUM_PHY_ID_MASK },
    { LY1211_PHY_ID, LINKYUM_PHY_ID_MASK },
    { LY1241_PHY_ID, LINKYUM_PHY_ID_MASK },
    {},
};

MODULE_DEVICE_TABLE(mdio, linkyum_phy_tbl);

MODULE_DESCRIPTION("Linkyum PHY driver");
MODULE_AUTHOR("Huxl");
MODULE_LICENSE("GPL");
