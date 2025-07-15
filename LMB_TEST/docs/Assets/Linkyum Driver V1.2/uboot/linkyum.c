/****************************************************************************
 *       Copyright (c) 2023 Shanghai Linkyum Microelectronics Co.           *                      
*****************************************************************************                                                                 
 * drivers/net/phy/linkyum.c
 *  
 * Description : Driver for Ly1211A/S PHYs.  
 * Version : V0.6
*****************************************************************************/
#include <common.h>
#include <phy.h>
#include <linux/mii.h>
#include <linux/ethtool.h>
#include <linux/compat.h>
#include <malloc.h>

/* Mask used for ID comparisons */
#define LINKYUM_PHY_ID_MASK                                    0xffffffff
/* LY1211 PHY IDs */
#define LY1211_PHY_ID                                          0xADB40412
/* PHY EXTRW OPSREG */
#define LY1211_EXTREG_ADDR                                     0x0E
#define LY1211_EXTREG_DATA                                     0x0D

#define LINKYUM_SPEC_REG                                       0x11

/* PHY LED */
#define LY1211_EXTREG_LED0                                     0x1E33   // 0
#define LY1211_EXTREG_LED1                                     0x1E34   // 00101111
#define LY1211_EXTREG_LED2                                     0x1E35   // 0x40

#define LINKYUM_PHY_RXC_DELAY_SET_ENABLE                       0
#define LINKYUM_PHY_CLK_OUT_125M_ENABLE                        1
#define LINKYUM_PHY_RXC_DELAY_VAL                              0x40

#define msleep(n)                udelay(n * 1000)

static int lyphy_read_ext(struct phy_device *phydev, u32 regnum)
{
    int ret, val, oldval;

    ret = phy_read(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR);
    if (ret < 0) {
        return ret;
	}
    oldval = ret;

    ret = phy_write(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR, regnum);
    if(ret < 0) {
        return ret;
    }
    ret = phy_read(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_DATA);
    if(ret < 0) {
        return ret;
    }
    val = ret;

    ret = phy_write(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) {
        return ret;
	}
    ret = val;

    return ret;
}

static int lyphy_write_ext(struct phy_device *phydev, u32 regnum, u16 val)
{
    int ret, oldval;

    ret = phy_read(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR);
    if (ret < 0) {
        return ret;
	}
    oldval = ret;

    ret = phy_write(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR, regnum);
    if(ret < 0) {
        return ret;
    }
    ret = phy_write(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_DATA, val);
    if(ret < 0) {
        return ret;
    }

    ret = phy_write(phydev, MDIO_DEVAD_NONE, LY1211_EXTREG_ADDR, oldval);
    if (ret < 0) {
        return ret;
	}
    ret = val;

    return ret;
}

static int ly1121_led_init(struct phy_device *phydev)
{
    int ret;

    ret = lyphy_write_ext(phydev, LY1211_EXTREG_LED0, 0x00);
    if(ret < 0) {
        return ret;
    }
    ret = lyphy_write_ext(phydev, LY1211_EXTREG_LED1, 0x2F);
    if(ret < 0) {
        return ret;
    }
        
    return lyphy_write_ext(phydev, LY1211_EXTREG_LED2, 0x40);
}

static int ly_soft_reset(struct phy_device *phydev)
{
    int ret = 0, val = 0;

    val = phy_read(phydev, MDIO_DEVAD_NONE, MII_BMCR);
    if (val < 0) {
        return val;
    }
    ret = phy_write(phydev, MDIO_DEVAD_NONE, MII_BMCR, val | BMCR_RESET);
    if(ret < 0) {
        return ret;
    }

    return ret;
}
#if LINKYUM_PHY_CLK_OUT_125M_ENABLE
static int ly1211_clkout_init(struct phy_device *phydev)
{
    int ret;

    ret = lyphy_read_ext(phydev, 0x0272);
    if(ret < 0) {
        return ret;
    }
    ret = lyphy_write_ext(phydev, 0x0272 , ret | 0x09);
    if(ret < 0) {
        return ret;
    }

    return ret;
}
#endif

static int ly1211_rxc_init(struct phy_device *phydev)
{
    int ret;
        
    // Init rxc and enable rxc
    ret = lyphy_read_ext(phydev, 0x1E0C);
    if(ret < 0) {
        return ret;
    }
    ret = lyphy_write_ext(phydev, 0x1E0C, (ret | 0x03));
    if(ret < 0) {
        return ret;
    }

#if LINKYUM_PHY_RXC_DELAY_SET_ENABLE
    // Init rxc delay 
    ret = lyphy_write_ext(phydev, 0x0282, LINKYUM_PHY_RXC_DELAY_VAL);
    if(ret < 0) {
        return ret;
    }
#endif

    return ret;
}

static int ly1211_config_opt(struct phy_device *phydev)
{
    int ret;

    ret = lyphy_write_ext(phydev, 0x0149 , 0x84);
    if(ret < 0) {
        return ret;
    }

    ret = lyphy_write_ext(phydev, 0x014A , 0x86);
    if(ret < 0) {
        return ret;
    }

    ret = lyphy_write_ext(phydev, 0x023C , 0x81);
    if(ret < 0) {
        return ret;
    }

    return ret;
}

static int ly1211_config(struct phy_device *phydev)
{
    int ret;

    ret = ly_soft_reset(phydev);
    if(ret < 0) {
        return ret;
    }
    msleep(10);

    ret = ly1211_rxc_init(phydev);
    if(ret < 0) {
        return ret;
    }

    ret = ly1211_config_opt(phydev);
    if(ret < 0) {
        return ret;
    }

    ret = ly1121_led_init(phydev);
    if(ret < 0) {
        return ret;
    }

#if LINKYUM_PHY_CLK_OUT_125M_ENABLE
    ret = ly1211_clkout_init(phydev);
    if(ret < 0) {
        return ret;
    }
#endif

    ret = genphy_config_aneg(phydev);
    if(ret < 0) {
        return ret;
    }

    return 0;
}


static int ly_update_status(struct phy_device *phydev)
{
    int ret;
    
    phydev->speed = SPEED_10;
    phydev->duplex = DUPLEX_HALF;

    ret = phy_read(phydev, MDIO_DEVAD_NONE, LINKYUM_SPEC_REG);
    if(ret < 0) {
        return ret;
    }

    if (ret & 0x02) 
        phydev->duplex = DUPLEX_FULL;
    if ((ret & 0x18) == 0x10) 
        phydev->speed = SPEED_1000;
    if ((ret & 0x18) == 0x08) 
        phydev->speed = SPEED_100;
    return 0;
}

static int ly_startup(struct phy_device *phydev)
{
    int ret;

    ret = genphy_update_link(phydev);
    if(ret < 0) {
        return ret;
    }
    ret = ly_update_status(phydev);
    if(ret < 0) {
        return ret;
    }
    // ret = ly_soft_reset(phydev);
    // if(ret < 0) {
    //     return ret;
    // }
    // msleep(10);

    return 0;
}

static struct phy_driver LY1211_driver = {
    .name          = "LY1211A_S Gigabit Ethernet",
    .uid           = LY1211_PHY_ID,
    .mask          = LINKYUM_PHY_ID_MASK,
    .features      = PHY_GBIT_FEATURES,
    .config        = &ly1211_config,
    .startup       = &ly_startup,
    .shutdown      = &genphy_shutdown,    
};


int phy_ly_init(void)
{
    phy_register(&LY1211_driver);

    return 0;
}

