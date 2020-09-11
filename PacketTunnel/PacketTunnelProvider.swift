//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by ZapCannon87 on 13/04/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import NetworkExtension

var Tunnel: PacketTunnelProvider?

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    var httpProxy: HTTPProxyServer?
    
    var  connection:NWTCPConnection!
    
    var tcpProxy: TCPProxyServer?
    
    var udpProxy: UDProxyServer?
    
    
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        
        NSLog("wuplyer ----  通道开启")
        
        Tunnel = self
        /* http */
        self.httpProxy = HTTPProxyServer()
        self.httpProxy!.start(with: "127.0.0.1")
        
        NSLog("wuplyer ----  当前localhost %@",self.httpProxy!.listenSocket.localHost!)
        NSLog("wuplyer ----  当前localport %d",self.httpProxy!.listenSocket.localPort)
        let host = self.httpProxy!.listenSocket.localHost!
        let port = self.httpProxy!.listenSocket.localPort
        
        let settings: NEPacketTunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        /* proxy settings */
        let proxySettings: NEProxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: host, port: Int(port))
        proxySettings.httpsServer = NEProxyServer(address: host, port: Int(port))
        proxySettings.autoProxyConfigurationEnabled = false
        //                proxySettings.httpEnabled = true
        //                proxySettings.httpsEnabled = true
        proxySettings.excludeSimpleHostnames = true
        proxySettings.exceptionList = ["192.168.0.0/16","10.0.0.0/8","172.16.0.0/12","127.0.0.1","localhost", "*.local"]
        settings.proxySettings = proxySettings
        /* ipv4 settings */
//       let ipv4Settings: NEIPv4Settings = NEIPv4Settings(addresses: ["127.0.0.1"],subnetMasks: ["255.255.255.255"])//127.0.0.1 回送地址 不会进行任何网络发送
        let ipv4Settings: NEIPv4Settings = NEIPv4Settings(addresses: ["192.168.0.2"],subnetMasks: ["255.255.255.255"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]//即vpn tunnel需要拦截包的地址，如果全部拦截则设置[NEIPv4Route defaultRoute]，也可以指定部分需要拦截的地址
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0")
        ]//设置不拦截哪些包的地址，默认不会拦截tunnel本身地址发出去的包
        settings.ipv4Settings = ipv4Settings
        /* MTU */
        settings.mtu = NSNumber(value: UINT16_MAX)
        
        
        
        let DNSSettings = NEDNSSettings(servers: ["198.18.0.1"])
        DNSSettings.matchDomains = [""]
        DNSSettings.matchDomainsNoSearch = false
        settings.dnsSettings = DNSSettings
        
        
        self.tcpProxy = TCPProxyServer()
        self.tcpProxy!.server.ipv4Setting( withAddress: settings.ipv4Settings!.addresses[0], netmask: settings.ipv4Settings!.subnetMasks[0])
        let mtuValue = settings.mtu!.uint16Value
        NSLog("wuplyer ----  最大的mtu值: %d",mtuValue)
        
        
        self.udpProxy = UDProxyServer()
        
        self.tcpProxy!.server.mtu(mtuValue) { datas, numbers in
            guard let _datas: [Data] = datas,let _nums: [NSNumber] = numbers else{return}
            NSLog("wuplyer ----  将数据写进应用")
            self.packetFlow.writePackets(_datas, withProtocols: _nums)
        }
        /* start */
        self.setTunnelNetworkSettings(settings) { err in
            completionHandler(err)
            if err == nil {
                NSLog("wuplyer ----  readPacket")
                
                //                if #available(iOSApplicationExtension 10.0, *) {
                //                    self.packetFlow.readPacketObjects { packeArray in
                //                        for (index, packe) in packeArray.enumerated() {
                //
                //                            //                                            NSLog("获取的数据来自\(String(describing: data.metadata?.sourceAppSigningIdentifier))")
                //                            //                                            data.metadata?.sourceAppSigningIdentifier
                //                            //                                            data.protocolFamily
                //
                //                            packe.data
                //                            packe.protocolFamily
                //
                //
                //                        }
                //                    }
                //                } else {
                //
                //                }
                
                self.packetFlow.readPackets() { datas, nums in
                    
                    NSLog("wuplyer ----  数据包数量 %d", datas.count)
                    NSLog("wuplyer ----  将数据读出")
                    self.handlePackets(packets: datas, protocols: nums)
                }
                
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        NSLog("wuplyer ----  通道关闭")
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        guard let message: String = String.init(data: messageData, encoding: .ascii) else {
            completionHandler?(nil)
            return
        }
        switch message {
        case "getSessionsData":
            SessionManager.shared.getSessionsData() { data in
                completionHandler?(data)
            }
        default:
            completionHandler?(nil)
        }
    }
    
    func handlePackets(packets: [Data], protocols: [NSNumber]) {
        for (index, data) in packets.enumerated() {
            
          
            
            switch protocols[index].int32Value {
            case AF_INET: /* internetwork: UDP, TCP, etc. */
                
                
                if IPPacket.peekProtocol(data) == .udp {
                    NSLog("wuplyer ----  捕获到UDP 数据")
                    
                    let desPort =  IPPacket.peekDestinationPort(data)
                   let desiIP =  IPPacket.peekDestinationAddress(data)
                    
                    let sourceIP = IPPacket.peekSourceAddress(data)
                    let sourcePort = IPPacket.peekSourcePort(data)
                    
                    
                    NSLog("wuplyer ----  捕获到UDP 源IP:\(String(describing: sourceIP))")
                    NSLog("wuplyer ----  捕获到UDP 源端口:\(String(describing: sourcePort))")
                    NSLog("wuplyer ----  捕获到UDP 目标IP:\(String(describing: desiIP))")
                    NSLog("wuplyer ----  捕获到UDP 目标端口:\(desPort ?? 9527)")
                    
                    
                    
                    
                    _ = self.udpProxy?.input(packet: data, version: protocols[index])
                }
                
                if IPPacket.peekProtocol(data) == .tcp {
                    NSLog("wuplyer ----  捕获到TCP 数据")
                    NSLog("wuplyer ----  tcp数据处理")
                    self.tcpProxy?.server.ipPacketInput(data)
                }
                
           
            case AF_INET6: //暂不支持IPV6
                break
            default:
                fatalError()
            }
        }
        self.packetFlow.readPackets { datas, numbers in
            self.handlePackets(packets: datas, protocols: numbers)
        }
    }
    
}
