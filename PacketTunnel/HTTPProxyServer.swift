//
//  HTTPProxyServer.swift
//  Sniffer
//
//  Created by ZapCannon87 on 23/04/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

class HTTPProxyServer: NSObject {
    
    let listenSocket: GCDAsyncSocket
    
    fileprivate var index: Int = 0
    
    fileprivate var connections: Set<HTTPConnection> = []
    
    override init() {
        self.listenSocket = GCDAsyncSocket()
        super.init()
        self.listenSocket.synchronouslySetDelegate(self,delegateQueue: DispatchQueue(label: "HTTPProxyServer.delegateQueue"))
    }
    
    func start(with host: String) {
        do {
            try self.listenSocket.accept(onInterface: host, port: 0)
        } catch {
            assertionFailure("\(error)")
        }
    }
    
    func remove(with connection: HTTPConnection) {
        self.listenSocket.delegateQueue!.async {
            self.connections.remove(connection)
        }
    }
    
}

extension HTTPProxyServer: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        
        NSLog("wuplyer http----  通道开启接收到新的socket 链接")
        NSLog("wuplyer http----  socket local host:%@", newSocket.localHost!)
        NSLog("wuplyer http----  socket local port:%d", newSocket.localPort)
        NSLog("wuplyer http----  socket connected host:%@", newSocket.connectedHost!)
        NSLog("wuplyer http----  socket connected port:%d", newSocket.connectedPort)
        
        let conn: HTTPConnection = HTTPConnection(index: self.index,incomingSocket: newSocket,server: self)
        self.index += 1
        self.connections.insert(conn)
    }
    
}
