//
//  TCPHandler.swift
//  Sniffer
//
//  Created by ZapCannon87 on 02/05/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import NetworkExtension


class TCPHandler: NSObject ,IPStackProtocol{
    
    
    public static var stack: TCPHandler {
        TSIPStack.stack.delegate = _stack
        TSIPStack.stack.processQueue = QueueFactory.getQueue()
        return _stack
    }
    fileprivate static let _stack: TCPHandler = TCPHandler()
    
    open weak var proxyServer: WUProxyServer?
    
    open var outputFunc: (([Data], [NSNumber]) -> Void)! {
           get {
               return TSIPStack.stack.outputBlock
           }
           set {
               TSIPStack.stack.outputBlock = newValue
           }
       }
    
    override init() {
        super.init()
    }

    
    //MARK: IPStackProtocol 实现
    func start() {}
    
   
    
    //数据输入 目前只能处理ipv4 将数据包输入到栈中
    public func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            if version.int32Value == AF_INET6{
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .tcp {
            NSLog("wuplyer TCP---- 获取tcp 数据包")
            TSIPStack.stack.received(packet: packet)
            return true
        }
        return false
    }
    
    fileprivate func inputData(_ packetData:Data){
        
    }
    
}



extension TCPHandler: TSIPStackDelegate {
    
    func didAcceptTCPSocket(_ sock: TSTCPSocket) {
        
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        
    }
    
}

