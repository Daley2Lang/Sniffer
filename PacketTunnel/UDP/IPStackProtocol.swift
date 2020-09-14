//
//  IPStackProtocol.swift
//  PacketTunnel
//
//  Created by Qi Liu on 2020/9/10.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

import Foundation
/// The protocol defines an IP stack.
public protocol IPStackProtocol: class {
    // 此参数一般为app write 数据
    ///当此堆栈决定输出某些IP数据包时调用此方法。当堆栈注册到某个接口时，此设置会自动设置。
    ///该参数作为“ inputPacket”是安全的。
    ///-注意：此块是线程安全的。
    
    var outputFunc: (([Data], [NSNumber]) -> Void)! { get set }
    
    /**
     将数据包输入到堆栈中。
     -参数包：IP包。
     -参数版本：IP数据包的版本，即AF_INET，AF_INET6。
     -返回：如果堆栈接收此数据包。如果数据包被接收，则其他IP堆栈将不会对其进行处理。 区分 ipv4  ipv6
     */
    func input(packet: Data, version: NSNumber?) -> Bool

    func start()

    /*
     停止堆栈运行。
     当注册该堆栈的接口停止处理数据包并将很快释放该接口时，将调用此方法。
     */
    func stop()
}

extension IPStackProtocol {
    public func stop() {}
}
