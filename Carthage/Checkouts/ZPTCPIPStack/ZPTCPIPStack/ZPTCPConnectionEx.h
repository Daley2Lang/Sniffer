//
//  ZPTCPConnectionEx.h
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#import "lwIP.h"

@class ZPPacketTunnel;

@interface ZPTCPConnection () {
    
    struct zp_tcp_block tcp_block; /* tcp block instance */
        
}

/**
 recommend set it use sync func, because that way can known whether tcp_pcb has already been aborted
 */
@property (nonatomic, weak) id<ZPTCPConnectionDelegate> delegate;

/**
 format: "\(source address)-\(source port)-\(destination address)-\(destination port)"
 */
@property (nonatomic, strong) NSString *identifie;

/**
 tunnel instance
 */
@property (nonatomic, weak) ZPPacketTunnel *tunnel;

/**
 tcp block pointer for tcp block instance, convenience for c func
 tcp块实例的tcp块指针，方便使用c func
 */
@property (nonatomic, assign) struct zp_tcp_block *block;

/**
 timer source mainly to call tcp_tmr() func at 0.25s interval
 定时器源主要以0.25s的间隔调用tcp_tmr（）函数
 */
@property (nonatomic, strong) dispatch_source_t timer;

/**
计时器源事件和所有API函数的串行队列
 */
@property (nonatomic, strong) dispatch_queue_t  timerQueue;

/**
使用此标志确定是否从tcp_pcb的接收缓冲区接收数据
 */
@property (nonatomic, assign) BOOL canReadData;

/**
 new tcp connection, this func not manage pbuf's memory
 新的tcp连接，此功能无法管理pbuf的内存
 */
+ (instancetype)newTCPConnectionWith:(ZPPacketTunnel *)tunnel
                           identifie:(NSString *)identifie
                              ipData:(struct ip_globals *)ipData
                             tcpInfo:(struct tcp_info *)tcpInfo
                                pbuf:(struct pbuf *)pbuf;

/**
 set tcp connection's source address and port, destination address and port’
 设置TCP连接的源地址和端口，目的地址和端口
 */
- (void)configSrcAddr:(NSString *)srcAddr
              srcPort:(UInt16)srcPort
             destAddr:(NSString *)destAddr
             destPort:(UInt16)destPort;

/**
 called by active tcp connection, this func will manage pbuf's memory
 */
- (void)tcpInputWith:(struct ip_globals)ipdata
             tcpInfo:(struct tcp_info)info
                pbuf:(struct pbuf *)pbuf;

@end
