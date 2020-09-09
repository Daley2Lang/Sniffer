//
//  ZPPacketTunnelEx.h
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#import "lwIP.h"

@class ZPTCPConnection;

@interface ZPPacketTunnel ()

/**
必须在调用`ipPacketInput：`之前设置
 */
@property (nonatomic, weak) id<ZPPacketTunnelDelegate> delegate;

/**
 ip数据输入block
 */
@property (nonatomic, copy) OutputBlock output;

/**
所有活动TCP连接的容器
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, ZPTCPConnection *> *dic;

/**
TCP连接dic的操作的串行队列：设置，获取和删除。用于线程安全
 */
@property (nonatomic, strong) dispatch_queue_t dicQueue;

/**
 lwIP的网络接口 包含数据处理的一切配置
 */
@property (nonatomic, assign) struct netif netif;

/**
通过TCP连接建立新的tcp连接时调用

 @param conn new tcp connection
 */
- (void)tcpConnectionEstablished:(ZPTCPConnection *)conn;

/**
异步。通过连接从dict删除tcp连接
 
 @param key tcp connection's identifie
 */
- (void)removeConnectionForKey:(NSString *)key;

/**
同步。通过隧道获得活动的TCP连接

 @param key tcp connection's identifie
 @return a active tcp connection
 */
- (ZPTCPConnection *)connectionForKey:(NSString *)key;

/**
 同步地。通过隧道将活动的TCP连接设置为dic
 @param conn a new active tcp connection
 @param key tcp connection's identifie
 */
- (void)setConnection:(ZPTCPConnection *)conn forKey:(NSString *)key;

@end
