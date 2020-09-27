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
    
    
    
    var interface: TUNInterface!
    
    var httpProxy: HTTPProxyServer?
    
    var connection:NWTCPConnection!
    
    var tcpProxy: TCPProxyServer!
    
    var udpProxy: UDProxyServer!
    
    var started:Bool = false
    
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        
        NSLog("wuplyer ----  通道开启")
        
        Tunnel = self
        _ = self.routingMethod
        
        /* http */
        self.httpProxy = HTTPProxyServer()
        self.httpProxy!.start(with: "127.0.0.1")
        
        NSLog("wuplyer ----  当前localhost %@",self.httpProxy!.listenSocket.localHost!)
        NSLog("wuplyer ----  当前localport %d",self.httpProxy!.listenSocket.localPort)
        let host = self.httpProxy!.listenSocket.localHost!
        let port = self.httpProxy!.listenSocket.localPort
        
        
        //MARK: 基础配置
        let settings: NEPacketTunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        /* proxy settings */
        let proxySettings: NEProxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: host, port: Int(port))
        proxySettings.httpsServer = NEProxyServer(address: host, port: Int(port))
        proxySettings.autoProxyConfigurationEnabled = false
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true
        proxySettings.excludeSimpleHostnames = true
        proxySettings.exceptionList = ["192.168.0.0/16",
                                       "10.0.0.0/8",
                                       "172.16.0.0/12",
                                       "127.0.0.1",
                                       "localhost",
                                       "*.local",
                                       
                                       "MicroWU.SendMsgTest",
                                       "api.smoot.apple.com",
                                       "configuration.apple.com",
                                       "xp.apple.com",
                                       "smp-device-content.apple.com",
                                       "guzzoni.apple.com",
                                       "captive.apple.com",
                                       "*.ess.apple.com",
                                       "*.push.apple.com",
                                       "*.push-apple.com.akadns.net"
        ]
        settings.proxySettings = proxySettings
        let ipv4Settings: NEIPv4Settings = NEIPv4Settings(addresses: ["192.168.0.2"],subnetMasks: ["255.255.255.255"])//开启新的网卡，并绑定ip，配置子网掩码127.0.0.1 回送地址 不会进行任何网络发送
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]//即vpn tunnel需要拦截包的地址，如果全部拦截则设置[NEIPv4Route defaultRoute]，也可以指定部分需要拦截的地址
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0")
        ]//设置不拦截哪些包的地址，默认不会拦截tunnel本身地址发出去的包
        
        settings.ipv4Settings = ipv4Settings
        settings.mtu = NSNumber(value: UINT16_MAX)
        
        let DNSSettings = NEDNSSettings(servers: ["198.18.0.1"])
        DNSSettings.matchDomains = [""]
        DNSSettings.matchDomainsNoSearch = false
        settings.dnsSettings = DNSSettings
        
        
        
        /* start */
        self.setTunnelNetworkSettings(settings) { err in
            completionHandler(err)
            if err == nil {
                //                NSLog("wuplyer ----  开始读取数据")
                //                if #available(iOSApplicationExtension 10.0, *) {
                //                    self.packetFlow.readPacketObjects { packeArray in
                //                        NSLog("wuplyer ----  数据包数量 %d", packeArray.count)
                //                        NSLog("wuplyer ----  将数据读出")
                //
                //                        var dataArray:[Data] = Array()
                //                        var protocolArray:[sa_family_t] = Array()
                //
                //                        for (_, packe) in packeArray.enumerated() {
                //                            dataArray.append(packe.data)
                //                            protocolArray.append(packe.protocolFamily)
                //                        }
                //                        self.handle(packets: dataArray, protocols: protocolArray as [NSNumber])
                //
                //                        dataArray.removeAll()
                //                        protocolArray.removeAll()
                //
                //                    }
                //                } else {
                //
                //                }
                //
                //                //                self.packetFlow.readPackets() { datas, nums in
                //                //
                //                //                    NSLog("wuplyer ----  数据包数量 %d", datas.count)
                //                //                    NSLog("wuplyer ----  将数据读出")
                //                //                    self.handlePackets(packets: datas, protocols: nums)
                //                //                }
                
            }
        }
        
        //MARK:三方库配置
        
        self.interface = TUNInterface(packetFlow: self.packetFlow)
        
        self.tcpProxy = TCPProxyServer()
        self.tcpProxy!.server.ipv4Setting( withAddress: settings.ipv4Settings!.addresses[0], netmask: settings.ipv4Settings!.subnetMasks[0])
//        _ = settings.mtu!.uint16Value
        
        self.udpProxy = UDProxyServer(packetFlow: self.packetFlow)
        UDProxyServer.TunnelProvider = self
        
        let fakeIPPool = try! IPPool(range: IPRange(startIP: IPAddress(fromString: "198.18.1.1")!, endIP: IPAddress(fromString: "198.18.255.255")!))
        let dnsServer = DNSServer(address: IPAddress(fromString: "198.18.0.1")!, port: Port(port: 53), fakeIPPool: fakeIPPool)
        let resolver = UDPDNSResolver(address: IPAddress(fromString: "114.114.114.114")!, port: Port(port: 53))
        dnsServer.registerResolver(resolver)
        DNSServer.currentServer = dnsServer
        
        self.interface.register(stack: dnsServer)
        self.interface.register(stack: self.udpProxy)
        self.interface.register(stack: self.tcpProxy)
        self.interface.start()
        
        
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
    
    
    
    
    
    func handle(packets: [Data], protocols: [NSNumber]) {
        
        NSLog("wuplyer ----  数据包的数量:\(packets.count)")
        
        for (index, data) in packets.enumerated() {
            
            switch protocols[index].int32Value {
            case AF_INET: /* internetwork: UDP, TCP, etc. */
                
                if IPPacket.peekProtocol(data) == .udp {
                    self.udpProxy?.input(packet: data, version: protocols[index])
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
        
        
        if #available(iOSApplicationExtension 10.0, *) {
            self.packetFlow.readPacketObjects { packeArray in
                
                var dataArray:[Data] = Array()
                var protocolArray:[sa_family_t] = Array()
                for (_, packe) in packeArray.enumerated() {
                    NSLog("wuplyer ----  数据包的来源")
                    _ = packe.metadata
                    NSLog("wuplyer ----  数据包的来源:\(String(describing: packe.metadata?.sourceAppSigningIdentifier))")
                    dataArray.append(packe.data)
                    protocolArray.append(packe.protocolFamily)
                }
                self.handle(packets: dataArray, protocols: protocolArray as [NSNumber])
                dataArray.removeAll()
                protocolArray.removeAll()
            }
        } else {
            
        }
    }
    
    
    func handlePackets(packets: [Data], protocols: [NSNumber]) {
        
        NSLog("wuplyer ----  数据包的数量:\(packets.count)")
        
        for (index, data) in packets.enumerated() {
            
            switch protocols[index].int32Value {
            case AF_INET: /* internetwork: UDP, TCP, etc. */
                
                if IPPacket.peekProtocol(data) == .udp {
                    self.udpProxy?.input(packet: data, version: protocols[index])
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
