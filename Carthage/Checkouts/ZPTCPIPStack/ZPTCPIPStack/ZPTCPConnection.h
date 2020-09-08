//
//  ZPTCPConnection.h
//  ZPTCPIPStack
//
//  Created by ZapCannon87 on 11/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZPTCPConnection;

@protocol ZPTCPConnectionDelegate <NSObject>

/**
 连接已接收到发送数据的确认后调用。

 @param connection TCP堆栈控制器
 @param length 传输数据的长度
 @param isEmpty True表示所有发送数据已完成传输或未发送任何数据，False表示缓冲区中存在发送数据以等待确认或重新发送
 */
- (void)connection:(ZPTCPConnection *_Nonnull)connection didWriteData:(UInt16)length sendBuf:(BOOL)isEmpty;

/**
 当连接设置了读取数据标志并且在tcp堆栈缓冲区中存在接收到的数据时调用。

 @param connection TCP堆栈控制器
 @param data 读取数据
 */
- (void)connection:(ZPTCPConnection *_Nonnull)connection didReadData:(NSData *_Nonnull)data;

/**
 当连接因错误而关闭时调用。

 @param connection TCP堆栈控制器
 @param err 错误关闭
 */
- (void)connection:(ZPTCPConnection *_Nonnull)connection didDisconnectWithError:(NSError *_Nonnull)err;

/**
 当连接在写入数据时检查错误时调用。

 @param connection TCP堆栈控制器
 @param err 写入数据时出错
 */
- (void)connection:(ZPTCPConnection *_Nonnull)connection didCheckWriteDataWithError:(NSError *_Nonnull)err;

/**
 如果读取流关闭，则有条件地调用，但是写入流可能仍然是可写的。
 
 @param connection TCP堆栈控制器
 */
@optional
- (void)connectionDidCloseReadStream:(ZPTCPConnection *_Nonnull)connection;

@end

@interface ZPTCPConnection : NSObject

/**
 Queue for delegate, it should be a serial queue.
 */
@property (nonatomic, strong, readonly, nonnull) dispatch_queue_t delegateQueue;

/**
 TCP connection source address.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *srcAddr;

/**
 TCP connection destination address.
 */
@property (nonatomic, strong, readonly, nonnull) NSString *destAddr;

/**
 TCP connection source port.
 */
@property (nonatomic, assign, readonly) UInt16 srcPort;

/**
 TCP connection destination port.
 */
@property (nonatomic, assign, readonly) UInt16 destPort;

/**
 Synchronously. Set the delegate and delegate queue.

 @param delegate can not be NULL
 @param queue can be NULL
 @return a flag to indicate whether the tcp_pcb has been aborted. False means tcp has aborted, True means tcp not aborted.
 */
- (BOOL)syncSetDelegate:(id<ZPTCPConnectionDelegate> _Nonnull)delegate delegateQueue:(dispatch_queue_t _Nullable)queue;

/**
 Asynchronously. Set the delegate and delegate queue.

 @param delegate can not be NULL
 @param queue can be NULL
 */
- (void)asyncSetDelegate:(id<ZPTCPConnectionDelegate> _Nonnull)delegate delegateQueue:(dispatch_queue_t _Nullable)queue;

/**
 Asynchronously. Writes data to the tcp_pcb, and calls the delegate when finished.

 @param data writing data
 */
- (void)write:(NSData *_Nonnull)data;

/**
 Asynchronously. This is not directly read the data in received buffer, it will set a flag up to let the tcp_pcb can read data from buffer. when the read delegate has been called, the flag will be set down.
 */
- (void)readData;

/**
 Asynchronously. Close the connection.
 */
- (void)close;

/**
 Asynchronously. Close the connection after all pending writes have completed.
 */
- (void)closeAfterWriting;

@end
