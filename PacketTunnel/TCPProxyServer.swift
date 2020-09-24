//
//  TCPProxyServer.swift
//  Sniffer
//
//  Created by ZapCannon87 on 02/05/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import NetworkExtension
import ZPTCPIPStack

class TCPProxyServer: NSObject ,IPStackProtocol{
    
    let server: ZPPacketTunnel
    fileprivate var index: Int = 0
    fileprivate var connections: Set<TCPConnection> = []
    
    override init() {
        self.server = ZPPacketTunnel.shared()
        super.init()
        self.server.setDelegate(self, delegateQueue: DispatchQueue(label: "TCPProxyServer.delegateQueue"))
        server.mtu(UInt16(UINT16_MAX)) {(datas, numbers) in
            NSLog("wuplyer TCP---- TCP 将数据写进应用")
            guard let _datas: [Data] = datas,let _nums: [NSNumber] = numbers else{return}
            self.outputFunc(_datas , _nums)
        }
    }
    
    func remove(connection: TCPConnection) {
        self.server.delegateQueue.async {
            self.connections.remove(connection)
        }
    }
    
    
    //MARK: IPStackProtocol 实现
    func start() {}
    
    public var outputFunc: (([Data], [NSNumber]) -> Void)!
    
    //数据输入 目前只能处理ipv4 将数据包输入到栈中
    public func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            if version.int32Value == AF_INET6{
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .tcp {
            NSLog("wuplyer TCP---- 获取tcp 数据包")
            self.server.ipPacketInput(packet)
            return true
        }
        return false
    }
    
    fileprivate func inputData(_ packetData:Data){
        
    }
    
}

extension TCPProxyServer: ZPPacketTunnelDelegate {
    func tunnel(_ tunnel: ZPPacketTunnel, didEstablishNewTCPConnection conn: ZPTCPConnection) {
        NSLog("wuplyer TCP----  通道开启接收到新的tcp 链接")
        if let tcpConn: TCPConnection = TCPConnection( index: self.index,localSocket: conn,server: self)
        {
            self.index += 1
            NSLog("wuplyer TCP----  当前任务量%d", self.index)
            self.connections.insert(tcpConn)
        }
    }
    
}

