//
//  WUProxyServer.swift
//  PacketTunnel
//
//  Created by Qi Liu on 2020/11/10.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

import Foundation
open class WUProxyServer: NSObject {
    typealias TunnelArray = [TCPChannel]
    
    var tunnels: TunnelArray = []
    
    public let port: Port
    
    public let address: IPAddress?
    
    public let type: String
    
    /// The description of proxy server.
    open override var description: String {
        return "<\(type) address:\(String(describing: address)) port:\(port)>"
    }
    
    public init(address: IPAddress?, port: Port) {
        self.address = address
        self.port = port
        type = "\(Swift.type(of: self))"
        super.init()
    }
    
 
    open func start() throws {
        QueueFactory.executeOnQueueSynchronizedly {
            GlobalIntializer.initalize()
        }
    }
    
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            for tunnel in tunnels {
                tunnel.forceClose()
            }
        }
    }

    func didAcceptNewSocket(_ socket: ProxySocket) {
        let tunnel = TCPChannel(proxySocket: socket)
        tunnel.delegate = self
        tunnels.append(tunnel)
        tunnel.openTunnel()
    }

}

extension WUProxyServer :TCPChannelDelegate{
    func tunnelDidClose(_ tunnel: TCPChannel) {
        guard let index = tunnels.firstIndex(of: tunnel) else {
                  return
              }
        tunnels.remove(at: index)
    }
}
