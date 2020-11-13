//
//  TCPConnection.swift
//  Sniffer
//
//  Created by ZapCannon87 on 02/05/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import ZPTCPIPStack

class TCPConnection: NSObject {
    
    let index: Int
    
    let local: ZPTCPConnection
    
    let remote: GCDAsyncSocket
    
    private(set) weak var server: TCPProxyServer?
    
    fileprivate let sessionModel: SessionModel = SessionModel()
    
    fileprivate var didClose: Bool = false
    
    fileprivate var didAddSessionToManager: Bool = false
    
    init?(index: Int, localSocket: ZPTCPConnection, server: TCPProxyServer) {
        
        self.index = index
        self.local = localSocket
        self.remote = GCDAsyncSocket()
        self.server = server
        super.init()
        let queue: DispatchQueue = DispatchQueue(label: "TCPConnection.delegateQueue")
        if !self.local.syncSetDelegate(self, delegateQueue: queue) {
            self.close(with: "Local TCP has aborted before connecting remote.")
            return nil
        }
        self.remote.synchronouslySetDelegate( self, delegateQueue: queue)
        do {
            try self.remote.connect(toHost: self.local.destAddr,onPort: self.local.destPort)
        } catch {
            self.close(with: "\(error)")
        }
    }
    
    override var hash: Int {
        return self.index
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs: TCPConnection = object as? TCPConnection else {
            return false
        }
        let lhs: TCPConnection = self
        return lhs.index == rhs.index
    }
    
    //关闭
    func close(with note: String) {
        guard !self.didClose else {
            return
        }
        self.didClose = true
        
        /* close connection */
        self.local.closeAfterWriting()
        self.remote.disconnectAfterWriting()
        self.server?.remove(connection: self)
    }
    
    
}

extension TCPConnection: ZPTCPConnectionDelegate {
    
    func connection(_ connection: ZPTCPConnection, didRead data: Data) {
        if data.count > 0 {
             let str = String.init(data: data, encoding: .utf8)
             NSLog("wuplyer TCP---- TCP接受 Tunnel 的数据:\(str ?? "")")
        }
        //远程soc
        self.remote.write(data, withTimeout: 5, tag: self.index)
    }
    
    func connection(_ connection: ZPTCPConnection, didWriteData length: UInt16, sendBuf isEmpty: Bool) {
        
        if isEmpty {
             NSLog("wuplyer TCP---- 将数据全部写入应用")
            self.remote.readData(withTimeout: -1, tag: self.index)
        }else{
             NSLog("wuplyer TCP---- 缓冲区中存在发送数据以等待确认或重新发送")
//            self.local.write(<#T##data: Data##Data#>)
        }
    }
    
    func connection(_ connection: ZPTCPConnection, didCheckWriteDataWithError err: Error) {
        
         NSLog("wuplyer TCP---- tun2sock 检查数据错误 链接错误:\(err)")
        
        self.close(with: "Local write: \(err)")
    }
    
    func connection(_ connection: ZPTCPConnection, didDisconnectWithError err: Error) {
         NSLog("wuplyer TCP---- tun2sock 断开连接 链接错误:\(err)")
        self.close(with: "Local: \(err)")
    }
    
}

extension TCPConnection: GCDAsyncSocketDelegate {
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        self.local.readData()
        self.remote.readData(withTimeout: -1, tag: self.index)
//        self.remote.readData(withTimeout: -1, buffer: nil, bufferOffset: 0, maxLength: UInt(UINT16_MAX / 2), tag: 0)
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        
        let str = String.init(data: data, encoding: .utf8)
        NSLog("wuplyer TCP---- TCP接受远程的数据:\(str ?? "")")
        self.local.write(data)
        
        self.remote.readData(withTimeout: -1, tag: tag)
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        self.local.readData()
        self.remote.readData(withTimeout: -1, tag: tag)
    }
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        self.close(with: "Remote: \(String(describing: err))")
    }
    
}
