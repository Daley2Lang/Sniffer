//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by ZapCannon87 on 13/04/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import NetworkExtension

var Tunnel: PacketTunnelProvider?

let DefaultIP = "127.0.0.1"

let DefaultPort = "9527"

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    //    http://hmrz.wo.cn/sdk-deliver/android/union-sdk-android-hmrz-v1.1.1.zip
    
    var enablePacketProcessing = false
    
    var started:Bool = false
    
    var interface: TUNInterface!
    
    var httpProxy: WUProxyServer?
    
    var connection:NWTCPConnection!
    
    var tcpProxy: TCPHandler!
    
    var udpProxy: UDProxyServer!
    
    
    var lastPath:NWPath?
    
    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        
        NSLog("wuplyer ----  通道开启")
        
        if !self.started{
            self.httpProxy = GCDHTTPProxyServer(address: IPAddress(fromString: DefaultIP), port: Port(port: UInt16(DefaultPort)!))
            try! self.httpProxy!.start()
            self.addObserver(self, forKeyPath: "defaultPath", options: .initial, context: nil)
        }else{
            self.httpProxy!.stop()
            try! self.httpProxy!.start()
        }
        
        //MARK: 基础配置
        let settings: NEPacketTunnelNetworkSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        /* proxy settings */
        let proxySettings: NEProxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(address: DefaultIP, port: Int(DefaultPort) ?? 9527)
        proxySettings.httpsServer = NEProxyServer(address: DefaultIP, port: Int(DefaultPort) ?? 9527)
        proxySettings.autoProxyConfigurationEnabled = false
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true
        proxySettings.excludeSimpleHostnames = true
        proxySettings.exceptionList = ["192.168.0.0/16",
                                       "192.168.0.2",
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
        //        let DNSSettings = NEDNSSettings(servers: ["114.114.114.114","8.8.8.8"])
        DNSSettings.matchDomains = [""]
        DNSSettings.matchDomainsNoSearch = false
        settings.dnsSettings = DNSSettings
        
        
        
        /* start */
        self.setTunnelNetworkSettings(settings) { err in
            completionHandler(err)
            
            guard err == nil else {
                NSLog("开启失败")
                completionHandler(err)
                return
            }
        
            completionHandler(nil)
            
        }
        
        //MARK:三方库配置
        
        self.interface = TUNInterface(packetFlow: self.packetFlow,tunnel: self)
        TUNInterface.TunnelProvider = self;
        
        let tcpS = TCPHandler.stack
        tcpS.proxyServer = self.httpProxy
        
        self.interface.register(stack: self.tcpProxy)
        
        self.udpProxy = UDProxyServer()
        self.interface.register(stack: self.udpProxy)
        
        let fakeIPPool = try! IPPool(range: IPRange(startIP: IPAddress(fromString: "198.18.1.1")!, endIP: IPAddress(fromString: "198.18.255.255")!))
        
        let dnsServer = DNSServer(address: IPAddress(fromString: "198.18.0.1")!, port: Port(port: 53), fakeIPPool: fakeIPPool)
        let resolver = UDPDNSResolver(address: IPAddress(fromString: "114.114.114.114")!, port: Port(port: 53))
        dnsServer.registerResolver(resolver)
        DNSServer.currentServer = dnsServer
        
        self.interface.register(stack: dnsServer)
        
        self.interface.start()
        
        
        
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if enablePacketProcessing {
            interface.stop()
            interface = nil
            DNSServer.currentServer = nil
        }
        
        if(httpProxy != nil){
            httpProxy?.stop()
            httpProxy = nil
            RawSocketFactory.TunnelProvider = nil
        }
        completionHandler()
        
        exit(EXIT_SUCCESS)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "defaultPath" {
            if self.defaultPath?.status == .satisfied && self.defaultPath != lastPath{
                if(lastPath == nil){
                    lastPath = self.defaultPath
                    
                    NSLog("wu_log:")
                    
                }else{
                    NSLog("wu_log:received network change notifcation")
                    let delayTime = DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                    DispatchQueue.main.asyncAfter(deadline: delayTime) {
                        self.startTunnel(options: nil){_ in}
                    }
                }
            }else{
                lastPath = defaultPath
            }
        }
        
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
    
}
