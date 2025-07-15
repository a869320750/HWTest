#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <linux/mii.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/sockios.h>
#include <linux/types.h>
#include <netinet/in.h>
#include <unistd.h>

#define retcheck(ret) \
        if(ret < 0){ \
            printf("%m! \"%s\" : line: %d\n", __func__, __LINE__); \
            goto lab; \
        }

#define help() \
    printf("[(<*** Linkyum MdioTool V1.0 ***>)]\r\n\r\n"); \
    printf("[Linkyum MdioBase/MdioExt Usage Method]\r\n\r\n"); \
    printf("Read  Operation:  ./mdio ethx RegAddr\r\n"); \
    printf("Write Operation:  ./mdio ethx RegAddr Val\r\n"); \
    printf("\r\nFor Example:\r\n"); \
    printf("./mdio ethx 0x00\r\n"); \
    printf("./mdio ethx 0x00 0x11\r\n\r\n"); \
    printf("[Linkyum \"New\" MdioExt Usage Method / Only Support ExtMdio !!!]\r\n\r\n"); \
    printf("Read  Operation:  ./mdio -n ethx RegAddr\r\n"); \
    printf("Write Operation:  ./mdio -n ethx RegAddr Val\r\n"); \
    printf("\r\nFor Example:\r\n"); \
    printf("./mdio -n ethx 0x00\r\n"); \
    printf("./mdio -n ethx 0x00 0x11\r\n\r\n"); \
    exit(0);

int sockfd;

int main(int argc, char *argv[])
{
    int ret;
    struct ifreq ifr;
    struct mii_ioctl_data *mii = NULL;

    if (argc == 1 || (!strcmp(argv[1], "-h"))) {
        help();
    }

    memset(&ifr, 0, sizeof(ifr));
    if (!strcmp(argv[1], "-n"))
        strncpy(ifr.ifr_name, argv[2], IFNAMSIZ - 1);
    else
        strncpy(ifr.ifr_name, argv[1], IFNAMSIZ - 1);
    mii = (struct mii_ioctl_data*)&ifr.ifr_data;

    sockfd = socket(PF_LOCAL, SOCK_DGRAM, 0);
    retcheck(sockfd);
    // init get phy address in smibus
    mii->reg_num = 0x0E;
    ret = ioctl(sockfd, SIOCGMIIPHY, &ifr);
    retcheck(ret);
        
    if (!strcmp(argv[1], "-n")) {
        if ((argc == 4) && ((uint16_t)strtoul(argv[3], NULL, 0) > 0x1F)) {
            mii->reg_num = 0x1E;
            mii->val_in = (uint16_t)strtoul(argv[3], NULL, 0);
            ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
            retcheck(ret);
            usleep(300);
            mii->reg_num = 0x1D;
            mii->val_in = 0x0400;
            ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
            retcheck(ret);
            usleep(300);
            mii->reg_num = 0x1D;
            ret = ioctl(sockfd, SIOCGMIIREG, &ifr);
            retcheck(ret);

            mii->reg_num = (uint16_t)strtoul(argv[3], NULL, 0);
            printf("[LinkYum]\tNewMdioExtRead\r\nPhy Addr: \t0x%x\r\nPhy  Reg: \t0x%x\r\nRead Val: \t0x%x\r\n", \
                    mii->phy_id, mii->reg_num, mii->val_out);
        } else if ((argc == 5) && ((uint16_t)strtoul(argv[3], NULL, 0) > 0x1F)) {
            mii->reg_num = 0x1E;
            mii->val_in = (uint16_t)strtoul(argv[3], NULL, 0);
            ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
            retcheck(ret);
            usleep(300);
            mii->reg_num = 0x1D;
            mii->val_in = (uint16_t)strtoul(argv[4], NULL, 0);
            mii->val_in = (0x0500 | mii->val_in);
            ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
            retcheck(ret);
            usleep(300);
            mii->reg_num = (uint16_t)strtoul(argv[3], NULL, 0);
            mii->val_in = (uint16_t)strtoul(argv[4], NULL, 0);

            printf("[LinkYum]\tNewMdioExtWrite\r\nPhy Addr: \t0x%x\r\nPhy  Reg: \t0x%x\r\nWrite Val: \t0x%x\r\n", \
                    mii->phy_id, mii->reg_num, mii->val_in);
        }
    } else {//old ext mdio read/write
        if ( argc == 3) {
            mii->reg_num = (uint16_t)strtoul(argv[2], NULL, 0);
            if (mii->reg_num > 0x1F) {
                mii->reg_num = 0x0E;
                mii->val_in = (uint16_t)strtoul(argv[2], NULL, 0);
                ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
                retcheck(ret);
                mii->reg_num = 0x0D;
                ret = ioctl(sockfd, SIOCGMIIREG, &ifr);
                retcheck(ret);
                mii->reg_num = (uint16_t)strtoul(argv[2], NULL, 0);
            } else {
                ret = ioctl(sockfd, SIOCGMIIREG, &ifr);
                retcheck(ret);
            }

            printf("[LinkYum]\tMdioRead\r\nPhy Addr: \t0x%x\r\nPhy  Reg: \t0x%x\r\nRead Val: \t0x%x\r\n", \
                    mii->phy_id, mii->reg_num, mii->val_out);
        } else if (argc == 4) {
            mii->reg_num = (uint16_t)strtoul(argv[2], NULL, 0);
            mii->val_in = (uint16_t)strtoul(argv[3], NULL, 0);
            if (mii->reg_num > 0x1F) {
                mii->reg_num = 0x0E;
                mii->val_in = (uint16_t)strtoul(argv[2], NULL, 0);
                ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
                retcheck(ret);
                mii->reg_num = 0x0D;
                mii->val_in = (uint16_t)strtoul(argv[3], NULL, 0);
                ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
                retcheck(ret);
                mii->reg_num = (uint16_t)strtoul(argv[2], NULL, 0);
                mii->val_in = (uint16_t)strtoul(argv[3], NULL, 0);
            } else {
                ret = ioctl(sockfd, SIOCSMIIREG, &ifr);
                retcheck(ret);
            }

            printf("[LinkYum]\tMdioWrite\r\nPhy Addr: \t0x%x\r\nPhy  Reg: \t0x%x\r\nWrite Val: \t0x%x\r\n", \
                    mii->phy_id, mii->reg_num, mii->val_in);
        }
    }


    close(sockfd);
    return 0;

lab:
    close(sockfd);
    return 0;
}
