//
//  ZPPacketTunnel.m
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#import "ZPPacketTunnel.h"
#import "ZPPacketTunnelEx.h"
#import "ZPTCPConnection.h"
#import "ZPTCPConnectionEx.h"
#import "IPTCPSegment.h"

void zp_debug_log(const char *message, ...)
{
#ifdef LWIP_DEBUG
    va_list args;
    va_start(args, message);
    NSLog(@"%@",[[NSString alloc] initWithFormat:[NSString stringWithUTF8String:message] arguments:args]);
    va_end(args);
#endif
}

err_t netif_output(struct pbuf *p, BOOL is_ipv4)
{
    void *buf = malloc(sizeof(char) * p->tot_len);
    LWIP_ASSERT("error in pbuf_copy_partial", pbuf_copy_partial(p, buf, p->tot_len, 0) != 0);
    
    NSData *data = [NSData dataWithBytesNoCopy:buf length:p->tot_len];
    NSNumber *ipVersion = [NSNumber numberWithInt:(is_ipv4 ? AF_INET : AF_INET6)];
    
    NSArray *datas = [NSArray arrayWithObject:data];
    NSArray *numbers = [NSArray arrayWithObject:ipVersion];
    
    //block 数据回调
    ZPPacketTunnel.shared.output(datas, numbers);  
    
    return ERR_OK;
}

err_t netif_output_ip4(struct netif *netif, struct pbuf *p, const ip4_addr_t *ipaddr)
{
    return netif_output(p, TRUE);
}

err_t netif_output_ip6(struct netif *netif, struct pbuf *p, const ip6_addr_t *ipaddr)
{
    return netif_output(p, FALSE);
}

// tcp输入预处理，检查并获取tcp数据包头中的信息。
void
tcp_input_pre(struct pbuf *p, struct netif *inp)
{
    NSLog(@"wuplyer TCP----  调用:tcp_input_pre");
    
    u8_t hdrlen_bytes;
    
    LWIP_UNUSED_ARG(inp);
    
    PERF_START;
    
    TCP_STATS_INC(tcp.recv);
    MIB2_STATS_INC(mib2.tcpinsegs);
    
    struct tcp_hdr * tcphdr = (struct tcp_hdr *)p->payload;
    
#if TCP_INPUT_DEBUG
    tcp_debug_print(tcphdr);
#endif
    
    /* Check that TCP header fits in payload */ //检查TCP标头是否适合有效负载
    if (p->len < TCP_HLEN) {
        /* drop short packets */
        LWIP_DEBUGF(TCP_INPUT_DEBUG, ("tcp_input: short packet (%"U16_F" bytes) discarded\n", p->tot_len));
        TCP_STATS_INC(tcp.lenerr);
        
        TCP_STATS_INC(tcp.drop);
        MIB2_STATS_INC(mib2.tcpinerrs);
        pbuf_free(p);
        return;
    }
    
    /*甚至不处理传入的广播/多播。 */
    if (ip_addr_isbroadcast(ip_current_dest_addr(), ip_current_netif()) ||
        ip_addr_ismulticast(ip_current_dest_addr())) {
        TCP_STATS_INC(tcp.proterr);
        
        TCP_STATS_INC(tcp.drop);
        MIB2_STATS_INC(mib2.tcpinerrs);
        pbuf_free(p);
        return;
    }
    
#if CHECKSUM_CHECK_TCP
    IF__NETIF_CHECKSUM_ENABLED(inp, NETIF_CHECKSUM_CHECK_TCP) {
        /*验证TCP校验和。 */
        u16_t chksum = ip_chksum_pseudo(p, IP_PROTO_TCP, p->tot_len,
                                        ip_current_src_addr(), ip_current_dest_addr());
        if (chksum != 0) {
            LWIP_DEBUGF(TCP_INPUT_DEBUG, ("tcp_input: packet discarded due to failing checksum 0x%04"X16_F"\n",
                                          chksum));
            tcp_debug_print(tcphdr);
            TCP_STATS_INC(tcp.chkerr);
            
            TCP_STATS_INC(tcp.drop);
            MIB2_STATS_INC(mib2.tcpinerrs);
            pbuf_free(p);
            return;
        }
    }
#endif /* CHECKSUM_CHECK_TCP */
    
    /* 完整性检查标头长度 */
    hdrlen_bytes = TCPH_HDRLEN(tcphdr) * 4;
    if ((hdrlen_bytes < TCP_HLEN) || (hdrlen_bytes > p->tot_len)) {
        LWIP_DEBUGF(TCP_INPUT_DEBUG, ("tcp_input: invalid header length (%"U16_F")\n", (u16_t)hdrlen_bytes));
        TCP_STATS_INC(tcp.lenerr);
        
        TCP_STATS_INC(tcp.drop);
        MIB2_STATS_INC(mib2.tcpinerrs);
        pbuf_free(p);
        return;
    }
    
    /* 将有效载荷指针移动到pbuf中，使其指向
     TCP数据而不是TCP标头。 */
    u16_t tcphdr_optlen = hdrlen_bytes - TCP_HLEN;
    u8_t* tcphdr_opt2 = NULL;
    u16_t tcphdr_opt1len;
    if (p->len >= hdrlen_bytes) {
        /* 所有选项都在第一个pbuf中 */
        tcphdr_opt1len = tcphdr_optlen;
        pbuf_header(p, -(s16_t)hdrlen_bytes); /* cannot fail */
    } else {
        u16_t opt2len;
        /* TCP标头适合第一个pbuf，选项不适合-数据位于下一个pbuf */
        /*由于上面的hdrlen_bytes完整性检查，因此必须有下一个pbuf */
        LWIP_ASSERT("p->next != NULL", p->next != NULL);
        
        /* 在TCP标头上前进（不能失败） */
        pbuf_header(p, -TCP_HLEN);
        
        /* 确定选项的第一部分和第二部分多长时间 */
        tcphdr_opt1len = p->len;
        opt2len = tcphdr_optlen - tcphdr_opt1len;
        
        /* 选项在下一个pbuf中继续：将p设置为零长度并隐藏
         下一个pbuf中的选项（调整p-> tot_len） */
        pbuf_header(p, -(s16_t)tcphdr_opt1len);
        
        /* 检查选项是否适合第二个pbuf */
        if (opt2len > p->next->len) {
            /* 丢弃短数据包 */
            LWIP_DEBUGF(TCP_INPUT_DEBUG, ("tcp_input: options overflow second pbuf (%"U16_F" bytes)\n", p->next->len));
            TCP_STATS_INC(tcp.lenerr);
            
            TCP_STATS_INC(tcp.drop);
            MIB2_STATS_INC(mib2.tcpinerrs);
            pbuf_free(p);
            return;
        }
        
        /* 记住指向选项第二部分的指针 */
        tcphdr_opt2 = (u8_t*)p->next->payload;
        
        /* 前进p-> next指向选项后的位置，然后手动
         调整p-> tot_len使其与更改的p-> next保持一致 */
        pbuf_header(p->next, -(s16_t)opt2len);
        p->tot_len -= opt2len;
        
        LWIP_ASSERT("p->len == 0", p->len == 0);
        LWIP_ASSERT("p->tot_len == p->next->tot_len", p->tot_len == p->next->tot_len);
    }
    
    /* 将TCP标头中的字段转换为主机字节顺序。 */
    tcphdr->src = lwip_ntohs(tcphdr->src);
    tcphdr->dest = lwip_ntohs(tcphdr->dest);
    u32_t seqno = tcphdr->seqno = lwip_ntohl(tcphdr->seqno);
    u32_t ackno = tcphdr->ackno = lwip_ntohl(tcphdr->ackno);
    tcphdr->wnd = lwip_ntohs(tcphdr->wnd);
    
    u8_t flags = TCPH_FLAGS(tcphdr);
    u16_t tcplen = p->tot_len + ((flags & (TCP_FIN | TCP_SYN)) ? 1 : 0);
    
    // 存储tcp标头信息的结构
    struct tcp_info tcpInfo = {
        .tcphdr         = tcphdr,
        .tcphdr_optlen  = tcphdr_optlen,
        .tcphdr_opt1len = tcphdr_opt1len,
        .tcphdr_opt2    = tcphdr_opt2,
        .seqno          = seqno,
        .ackno          = ackno,
        .tcplen         = tcplen,
        .flags          = flags
    };
    
    /* 获取TCP pcb标识符*/
    int addr_str_len = ip_current_is_v6() ? INET6_ADDRSTRLEN : INET_ADDRSTRLEN;
    char src_addr_chars[addr_str_len];
    char dest_addr_chars[addr_str_len];
    if (ip_current_is_v6()) {
        LWIP_ASSERT("error in ip6 ntop",
                    inet_ntop(AF_INET6, ip6_current_src_addr(), src_addr_chars, addr_str_len) != NULL);
        LWIP_ASSERT("error in ip6 ntop",
                    inet_ntop(AF_INET6, ip6_current_dest_addr(), dest_addr_chars, addr_str_len) != NULL);
    } else {
        LWIP_ASSERT("error in ip4 ntop",
                    inet_ntop(AF_INET, ip4_current_src_addr(), src_addr_chars, addr_str_len) != NULL);
        LWIP_ASSERT("error in ip4 ntop",
                    inet_ntop(AF_INET, ip4_current_dest_addr(), dest_addr_chars, addr_str_len) != NULL);
    }
    NSString *src_addr_str = [NSString stringWithCString:src_addr_chars encoding:NSASCIIStringEncoding];
    NSString *dest_addr_str = [NSString stringWithCString:dest_addr_chars encoding:NSASCIIStringEncoding];
    NSString *identifie = [NSString stringWithFormat:@"%@-%d-%@-%d", src_addr_str, tcphdr->src, dest_addr_str, tcphdr->dest];
    
    
 
    
    //
    ZPTCPConnection *conn = [ZPPacketTunnel.shared connectionForKey:identifie];
    if (conn) {
//        NSLog(@"wuplyer TCP----  已有 ZPTCPConnection 对象");
        [conn tcpInputWith:ip_data
                   tcpInfo:tcpInfo
                      pbuf:p];
    } else {
        if (identifie) {
             NSLog(@"wuplyer TCP----  当前数据的源ip:%@,源端口:%d-----目标ip:%@,目标端口:%d",src_addr_str, tcphdr->src, dest_addr_str, tcphdr->dest);
         }
//         NSLog(@"wuplyer TCP----  没有 ZPTCPConnection 对象,创建新的对象");
        conn = [ZPTCPConnection newTCPConnectionWith:ZPPacketTunnel.shared
                                           identifie:identifie
                                              ipData:&ip_data
                                             tcpInfo:&tcpInfo
                                                pbuf:p];
        if (conn) {
            [conn configSrcAddr:src_addr_str
                        srcPort:tcphdr->src
                       destAddr:dest_addr_str
                       destPort:tcphdr->dest];
            [ZPPacketTunnel.shared setConnection:conn forKey:identifie];
        }
        pbuf_free(p);
    }
}

@implementation ZPPacketTunnel

+ (instancetype)shared
{
    static dispatch_once_t once;
    static id shared;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dic = [[NSMutableDictionary alloc] init];
        _dicQueue = dispatch_queue_create("ZPPacketTunnel.dicQueue", NULL);
    }
    return self;
}

- (void)setDelegate:(id<ZPPacketTunnelDelegate> _Nonnull)delegate
      delegateQueue:(dispatch_queue_t _Nullable)queue;
{
    _delegate = delegate;
    if (queue) {
        _delegateQueue = queue;
    } else {
        _delegateQueue = dispatch_queue_create("ZPPacketTunnel.delegateQueue", NULL);
    }
}
//数据回调
-(void)mtu:(UInt16)mtu output:(OutputBlock)output
{
    _netif.mtu = mtu;
    _output = output;
}


//开始
-(void)ipv4SettingWithAddress:(NSString *)addr netmask:(NSString *)netmask
{
    NSLog(@"wuplyer TCP----  tcp 开启的地址%@",addr);
    NSLog(@"wuplyer TCP----  tcp 开启的子网掩码%@",netmask);
    struct netif *netif = &_netif;
    /* 配置地址 */
    ip4_addr_t ip4_addr;
    const char *addr_chars = [addr cStringUsingEncoding:NSASCIIStringEncoding];
    NSAssert(inet_pton(AF_INET, addr_chars, &ip4_addr) != 0 && !ip4_addr_isany(&ip4_addr),
             @"error in ipv4 address");
    ip4_addr_set(ip_2_ip4(&netif->ip_addr), &ip4_addr);
    IP_SET_TYPE_VAL(netif->ip_addr, IPADDR_TYPE_V4);
    
    /* 配置子网掩码 */
    ip4_addr_t ip4_netmask;
    const char *netmask_chars = [netmask cStringUsingEncoding:NSASCIIStringEncoding];
    NSAssert(inet_pton(AF_INET, netmask_chars, &ip4_netmask) != 0,
             @"error in ipv4 netmask");
    ip4_addr_set(ip_2_ip4(&netif->netmask), &ip4_netmask);
    IP_SET_TYPE_VAL(netif->netmask, IPADDR_TYPE_V4);
    
    /* 配置网关地址 */
    ip4_addr_set(ip_2_ip4(&netif->gw), &ip4_addr);
    IP_SET_TYPE_VAL(netif->gw, IPADDR_TYPE_V4);
    
    netif->output = netif_output_ip4; //给iwip 对象关联输出函数
}


// MARK: - IP
// 数据输入
- (err_t)ipPacketInput:(NSData *)data
{
    NSLog(@"wuplyer TCP----  tunnel 数据包输入 ");
    NSAssert(data.length <= _netif.mtu, @"error in data length or mtu value");
    
    /* copy data bytes to pbuf */
    struct pbuf *p = pbuf_alloc(PBUF_RAW, data.length, PBUF_RAM);
    NSAssert(p != NULL, @"error in pbuf_alloc");
    NSAssert(pbuf_take(p, data.bytes, data.length) == ERR_OK, @"error in pbuf_take");
    
    if (IP_HDR_GET_VERSION(p->payload) == 6) {
        NSLog(@"wuplyer TCP----  IPV6 数据");
        return ip6_input(p, &_netif);
    } else {
//        NSLog(@"wuplyer TCP----  IPV4 数据");
        return ip4_input(p, &_netif);
    }
}

// MARK: - Misc 连接成功
- (void)tcpConnectionEstablished:(ZPTCPConnection *)conn
{
    NSAssert(_delegateQueue, @"Not set delegate queue");
    dispatch_async(_delegateQueue, ^{
        if (_delegate) {
            [_delegate tunnel:self didEstablishNewTCPConnection:conn];
        }
    });
}

- (ZPTCPConnection *)connectionForKey:(NSString *)key
{
    //同步取
    __block ZPTCPConnection *conn = NULL;
    dispatch_sync(_dicQueue, ^{
        conn = [_dic objectForKey:key];
    });
    return conn;
}

- (void)setConnection:(ZPTCPConnection *)conn forKey:(NSString *)key
{
    //同步存
    dispatch_sync(_dicQueue, ^{
        [_dic setObject:conn forKey:key];
    });
}

- (void)removeConnectionForKey:(NSString *)key
{//异步删除
    dispatch_async(_dicQueue, ^{
        [_dic removeObjectForKey:key];
    });
}

@end
