//
//  IPStackProtocol.swift
//  PacketTunnel
//
//  Created by Qi Liu on 2020/9/10.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

import Foundation
/// 该协议定义了一个IP堆栈。
public protocol IPStackProtocol: class {
    
    var outputFunc: (([Data], [NSNumber]) -> Void)! { get set }

    func input(packet: Data, version: NSNumber?) -> Bool

    func start()

    func stop()
}

extension IPStackProtocol {
    public func stop() {}
}
