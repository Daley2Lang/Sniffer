//
//  ZPPacketTunnel.h
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^OutputBlock)(NSArray<NSData *> *_Nullable packets, NSArray<NSNumber *> *_Nullable protocols);

@class ZPPacketTunnel;
@class ZPTCPConnection;

@protocol ZPPacketTunnelDelegate <NSObject>

/**
 建立新的tcp连接时调用。

 @paramtunnel ip数据隧道管理器
 @param conn 新的tcp连接
 */
- (void)tunnel:(ZPPacketTunnel *_Nonnull)tunnel didEstablishNewTCPConnection:(ZPTCPConnection *_Nonnull)conn;

@end

@interface ZPPacketTunnel : NSObject

/**
 对于委托队列，它应该是一个串行队列。
 */
@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t delegateQueue;

- (instancetype _Nonnull)init NS_UNAVAILABLE;
+ (instancetype _Nonnull)new NS_UNAVAILABLE;

/**
 Singleton

 @return tunnel instance
 */
+ (instancetype _Nonnull)shared;

/**
 设置委托和委托队列，必须在`ipPacketInput：`之前调用。

 @param delegate 不能为NULL
 @param queue 可以为NULL
 */
- (void)setDelegate:(id<ZPPacketTunnelDelegate> _Nonnull)delegate delegateQueue:(dispatch_queue_t _Nullable)queue;

/**
 设置MTU和隧道ip数据输出块，必须在ipPacketInput：之前调用。

 @param mtu 不支持TCP win标度，因此最大数量为uint16_max
 @param output ip数据输出块
 */
- (void)mtu:(UInt16)mtu output:(OutputBlock _Nonnull)output;

/**
 设置隧道ipv4地址和子网掩码，必须在ipPacketInput：之前调用。

 @param addr  ipv4地址
 @param netmask 子网掩码
 */
- (void)ipv4SettingWithAddress:(NSString *_Nonnull)addr netmask:(NSString *_Nonnull)netmask;

/**
 IP数据包输入，接受ipv4和ipv6数据。
 
 @param data ip数据
 @return 0表示确定
 */
- (SInt8)ipPacketInput:(NSData *_Nonnull)data;

@end
