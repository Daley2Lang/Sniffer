//
//  lwIP.h
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#ifndef lwIP_h
#define lwIP_h

#import <netinet/in.h>

#include "lwip/tcp.h"
#include "lwip/prot/tcp.h"
#include "lwip/priv/tcp_priv.h"
#include "lwip/inet_chksum.h"
#include "lwip/ip4_frag.h"
#include "lwip/ip6_frag.h"

#if LWIP_IPV4 && LWIP_IPV6 /* LWIP_IPV4 && LWIP_IPV6 */

#define inet_ntop(af,src,dst,size) \
(((af) == AF_INET6) ? ip6addr_ntoa_r((const ip6_addr_t*)(src),(dst),(size)) \
: (((af) == AF_INET) ? ip4addr_ntoa_r((const ip4_addr_t*)(src),(dst),(size)) : NULL))
#define inet_pton(af,src,dst) \
(((af) == AF_INET6) ? ip6addr_aton((src),(ip6_addr_t*)(dst)) \
: (((af) == AF_INET) ? ip4addr_aton((src),(ip4_addr_t*)(dst)) : 0))

#elif LWIP_IPV4 /* LWIP_IPV4 */

#define inet_ntop(af,src,dst,size) \
(((af) == AF_INET) ? ip4addr_ntoa_r((const ip4_addr_t*)(src),(dst),(size)) : NULL)
#define inet_pton(af,src,dst) \
(((af) == AF_INET) ? ip4addr_aton((src),(ip4_addr_t*)(dst)) : 0)

#else /* LWIP_IPV6 */

#define inet_ntop(af,src,dst,size) \
(((af) == AF_INET6) ? ip6addr_ntoa_r((const ip6_addr_t*)(src),(dst),(size)) : NULL)
#define inet_pton(af,src,dst) \
(((af) == AF_INET6) ? ip6addr_aton((src),(ip6_addr_t*)(dst)) : 0)

#endif /* LWIP_IPV4 && LWIP_IPV6 */


/**
 struct to store tcp header info
 存储tcp标头信息的结构
 */
struct tcp_info {
    /* 这些变量是输入中涉及的所有功能的全局变量
    TCP段的处理。它们由tcp_input_pre（）设置
    功能. */
    struct tcp_hdr *tcphdr;
    u16_t tcphdr_optlen;
    u16_t tcphdr_opt1len;
    u8_t* tcphdr_opt2;
    u32_t seqno;
    u32_t ackno;
    u16_t tcplen;
    u8_t  flags;
};

/**
  
  将所有tcp堆栈全局信息存储到lwIP的tcp堆栈中涉及的所有功能的结构
 */
struct zp_tcp_block {
    
    struct tcp_pcb *pcb;
    
    struct ip_globals ip_data;
    
    struct tcp_info tcpInfo;
    
    /* Incremented every coarse grained timer shot (typically every 500 ms).
     每个粗粒度的计时器射击（通常每500毫秒）增加一次。  ?????????
     */
    u32_t tcp_ticks;
    /* Timer counter to handle calling slow-timer from tcp_tmr()
       计时器计数器，用于处理从tcp_tmr（）调用慢速计时器
     */
    uint64_t tcp_timer;
    
    /*
    这些变量是输入中涉及的所有功能的全局变量
         TCP段的处理。它们由tcp_input（）设置
         功能. */
    u16_t          tcp_optidx;
    struct tcp_seg inseg;
    struct pbuf    *recv_data;
    u8_t           recv_flags;
    tcpwnd_size_t  recv_acked;
    
    /*
    所有未完成的写操作完成后，用于控制tcp关闭的标志*/
    u8_t close_after_writing;
    
};

/**
 
 tcp输入预处理，检查并获取tcp数据包头中的信息。

 @param p tcp data pbuf
 @param inp input network interface
 */
void tcp_input_pre(struct pbuf *p, struct netif *inp);

#endif /* lwIP_h */
