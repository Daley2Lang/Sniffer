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
        //
        NSLog("wuplyer ---- 得到UDP数据")
        
        let desPort =  IPPacket.peekDestinationPort(packetData)
        let desiIP =  IPPacket.peekDestinationAddress(packetData)
        
        let sourceIP = IPPacket.peekSourceAddress(packetData)
        let sourcePort = IPPacket.peekSourcePort(packetData)
        
        
        NSLog("wuplyer ----  捕获到UDP 源IP:\(String(describing: sourceIP))")
        NSLog("wuplyer ----  捕获到UDP 源端口:\(sourcePort ?? 9527)")
        NSLog("wuplyer ----  捕获到UDP 目标IP:\( String(describing: desiIP))")
        NSLog("wuplyer ----  捕获到UDP 目标端口:\(desPort ?? 9527)")
                   
                   
                   
        
        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.write(data: payload!)
    }
    
    //针对数据创建socket
    fileprivate func findOrCreateSocketForPacket(_ packet: IPPacket) -> (ConnectInfo, NWUDPSocket)? {
      
        let udpParser = packet.protocolParser as! UDPProtocolParser
        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)
        
        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
            return (connectInfo, socket)
        }
        
        guard let session = ConnectSession(ipAddress: connectInfo.destinationAddress, port: connectInfo.destinationPort) else {
            return nil
        }
        
        
        NSLog("wuplyer ---- 创建udp 链接的host:\(session.host) 和 port:\(session.port)")
        
        guard let udpSocket = NWUDPSocket(host: session.host, port: session.port) else {
            return nil
        }
        
    
         NSLog("wuplyer ---- 创建 udp socket")
        udpSocket.delegate = self
        queueServer.sync {
            self.activeSockets[connectInfo] = udpSocket
        }
        return (connectInfo, udpSocket)
        //        return nil
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
    
    
//
//    fileprivate func generateOutputBlock() -> ([Data], [NSNumber]) -> Void {
//          return { [weak self] packets, versions in
//              self?.packetFlow?.writePackets(packets, withProtocols: versions)
//          }
//      }
    
}

extension UDProxyServer :NWUDPSocketDelegate{
    public func didReceive(data: Data, from: NWUDPSocket) {
        
        let str = String.init(data: data, encoding: .utf8)
        NSLog("wuplyer ---- NWUDPSocketDelegate 进行 数据会回调,回调的数据:\(String(describing: str))")
        
        guard let (connectInfo, _) = findSocket(connectInfo: nil, socket: from) else {
            return
        }
        
        let packet = IPPacket()
        packet.sourceAddress = connectInfo.destinationAddress
        packet.destinationAddress = connectInfo.sourceAddress
        let udpParser = UDPProtocolParser()
        
        udpParser.sourcePort = connectInfo.destinationPort
        udpParser.destinationPort = connectInfo.sourcePort
        udpParser.payload = data
        packet.protocolParser = udpParser
        packet.transportProtocol = .udp
        packet.buildPacket()
        
         NSLog("wuplyer UDP---- 将数据写进app")
        
        outputFunc([packet.packetData], [NSNumber(value: AF_INET as Int32)])
    }
    
    public func didCancel(socket: NWUDPSocket) {
        guard let (info, _) = findSocket(connectInfo: nil, socket: socket) else {
            return
        }
        
        activeSockets.removeValue(forKey: info)
    }
    
    
}
