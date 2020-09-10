//
//  UDProxyServer.swift
//  PacketTunnel
//
//  Created by Qi Liu on 2020/9/10.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

import Foundation
import NetworkExtension

struct ConnectInfo {
    let sourceAddress: IPAddress
    let sourcePort: Port
    let destinationAddress: IPAddress
    let destinationPort: Port
}

extension ConnectInfo: Hashable {}

func == (left: ConnectInfo, right: ConnectInfo) -> Bool {
    return left.destinationAddress == right.destinationAddress &&
        left.destinationPort == right.destinationPort &&
        left.sourceAddress == right.sourceAddress &&
        left.sourcePort == right.sourcePort
}


public class UDProxyServer:IPStackProtocol {
    
    ///当前活动的NETunnelProvider，它创建NWTCPConnection实例。
    ///-注意：如果使用`NWTCPSocket`或`NWUDPSocket`，则必须在创建任何连接之前进行设置。
    public static weak var TunnelProvider: NETunnelProvider?
    
    fileprivate var activeSockets:[ConnectInfo:NWUDPSocket] = [:]
    
    fileprivate let queueServer : DispatchQueue = DispatchQueue(label: "NEKit.UDPDirectStack.SocketArrayQueue", attributes: [])
    
    public init() {}
    
    public func start() {
        
    }
    public func stop() {
        queueServer.async {
            for socket in self.activeSockets.values {
                socket.disconnect()
            }
            self.activeSockets = [:]
        }
    }
    
    
    //IPStackProtocol 实现
    public var outputFunc: (([Data], [NSNumber]) -> Void)!
    
    //数据输入 目前只能处理ipv4 将数据包输入到栈中
    public func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            if version.int32Value == AF_INET6{
                return false
            }
        }
            if IPPacket.peekProtocol(packet) == .udp {
                inputData(packet)
                return true
            }
            return false
    }
        
    
    fileprivate func inputData(_ packetData:Data){
        //处理和构建IP数据包的类。
        guard let packet = IPPacket(packetData: packetData) else {
            return
        }
        
        guard let (_, socket) = findOrCreateSocketForPacket(packet) else {
            return
        }
        
        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.write(data: payload!)
    }
    
    //针对数据创建socket
    fileprivate func findOrCreateSocketForPacket(_ packet: IPPacket) -> (ConnectInfo, NWUDPSocket)? {
        // swiftlint:disable:next force_cast
//        let udpParser = packet.protocolParser as! UDPProtocolParser
//        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)
//
//        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
//            return (connectInfo, socket)
//        }
//
//        guard let session = ConnectSession(ipAddress: connectInfo.destinationAddress, port: connectInfo.destinationPort) else {
//            return nil
//        }
//
//        guard let udpSocket = NWUDPSocket(host: session.host, port: session.port) else {
//            return nil
//        }
//
//        udpSocket.delegate = self
//        queueServer.sync {
//            self.activeSockets[connectInfo] = udpSocket
//        }
//        return (connectInfo, udpSocket)
        return nil
    }
    
    
    
    
       fileprivate func findSocket(connectInfo: ConnectInfo?, socket: NWUDPSocket?) -> (ConnectInfo, NWUDPSocket)? {
            var result: (ConnectInfo, NWUDPSocket)?

            queueServer.sync {
                if connectInfo != nil {
                    guard let sock = self.activeSockets[connectInfo!] else {
                        result = nil
                        return
                    }
                    result = (connectInfo!, sock)
                    return
                }

                guard let socket = socket else {
                    result = nil
                    return
                }

                guard let index = self.activeSockets.firstIndex(where: { _, sock in
                    return socket === sock
                }) else {
                    result = nil
                    return
                }

                result = self.activeSockets[index]
            }
            return result
        }
    
}

