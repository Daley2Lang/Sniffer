//
//  TCPConnection.swift
//  Sniffer
//
//  Created by ZapCannon87 on 02/05/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import CocoaAsyncSocket
import NetworkExtension
import ZPTCPIPStack

class TCPConnection: NSObject {
    
    let index: Int
    
    let local: ZPTCPConnection
    
    let remote: GCDAsyncSocket
    
    var newRemote: NWTCPConnection?
    
    private var cancelled = false
    
    private var writePending = false
    
    private var closeAfterWriting = false
    
    private var scanning: Bool = false
    
    private var scanner: StreamScanner!
    
    private(set) weak var server: TCPProxyServer?
    
    fileprivate let sessionModel: SessionModel = SessionModel()
    
    fileprivate var didClose: Bool = false
    
    fileprivate var didAddSessionToManager: Bool = false
    
    private var readDataPrefix: Data?
    
    init?(index: Int, localSocket: ZPTCPConnection, server: TCPProxyServer) {
        
        self.index = index
        self.local = localSocket
        self.remote = GCDAsyncSocket()
        
        self.newRemote = NWTCPConnection()
        
        self.server = server
        
        super.init()
        
        let queue: DispatchQueue = DispatchQueue(label: "TCPConnection.delegateQueue")
        if !self.local.syncSetDelegate(self, delegateQueue: queue) {
            self.close(with: "Local TCP has aborted before connecting remote.")
            return nil
        }
//        self.remote.synchronouslySetDelegate( self, delegateQueue: queue)
        
        
        let endpoint = NWHostEndpoint(hostname: self.local.destAddr, port: "\(self.local.destPort)")

        let tlsParameters = NWTLSParameters()

        guard let connection = TUNInterface.TunnelProvider?.createTCPConnection(to: endpoint, enableTLS: false, tlsParameters: tlsParameters, delegate: nil) else {
            return
        }
        self.newRemote = connection
        connection.addObserver(self, forKeyPath: "state", options: [.initial, .new], context: nil)
//
//        do {
//            // NSLog("wuplyer TCP---- 远程开始连接，目标ip：\(self.local.destAddr),目标端口:\(self.local.destPort)")
//            try self.remote.connect(toHost: self.local.destAddr,onPort: self.local.destPort)
//        } catch {
//            self.close(with: "\(error)")
//        }
    }

    
    
    //MARK: 原来的工程

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
      
    
}




extension TCPConnection{
    
    private func queueCall(_ block: @escaping () -> Void) {
        QueueFactory.getQueue().async(execute: block)
    }
    
    
    // local 读取之后 即将写入远程
    public func write(data: Data) {
        guard !cancelled else {
            return
        }

        guard data.count > 0 else {
            QueueFactory.getQueue().async {
    
                self.local.readData() //没有数据local 继续读
//                self.delegate?.didWrite(data: data, by: self)
            }
            return
        }

        send(data: data)
    }

    //NWTCPConnection 开始读取数据
    public func readData() {
        guard !cancelled else {
            return
        }
        
        newRemote!.readMinimumLength(1, maximumLength: Opt.MAXNWTCPSocketReadDataSize) { data, error in
            guard error == nil else {
                
                self.queueCall {
                    self.close(with: "")
                }
                return
            }
            
            self.readCallback(data: data)
        }
    }
    
    public func readDataTo(length: Int) {
        guard !cancelled else {
            return
        }
        
        newRemote!.readLength(length) { data, error in
            guard error == nil else {
                NSLog("NWTCPSocket got an error when reading data: \(String(describing: error))")
                self.queueCall {
                    self.disconnect()
                }
                return
            }
            self.readCallback(data: data)
        }
    }
    
    
    public func readDataTo(data: Data) {
        readDataTo(data: data, maxLength: 0)
    }
    
    public func readDataTo(data: Data, maxLength: Int) {
        guard !cancelled else {
            return
        }
        
        var maxLength = maxLength
        if maxLength == 0 {
            maxLength = Opt.MAXNWTCPScanLength
        }
        scanner = StreamScanner(pattern: data, maximumLength: maxLength)
        scanning = true
        readData()
    }
    
    
    
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "state" else {
            return
        }
        NSLog("NWTCPConnection 的链接状态\(newRemote!.state)")
        
        switch newRemote!.state {
        case .connected:
            queueCall {
                //                  self.delegate?.didConnectWith(socket: self)
            }
        case .disconnected:
            cancelled = true
            newRemote!.cancel()
        case .cancelled:
            cancelled = true
            queueCall {
                
            }
        default:
            break
        }
    }
    
    private func readCallback(data: Data?) {
        guard !cancelled else {
            return
        }
        
        queueCall {
            guard let data = self.consumeReadData(data) else {
                //
                //远程读取已关闭，但这没关系，无需执行任何操作，如果再次读取此套接字，则会发生错误。
                return
            }
            
            if self.scanning {
                guard let (match, rest) = self.scanner.addAndScan(data ) else {
                    self.readData()
                    return
                }
                
                self.scanner = nil
                self.scanning = false
                
                guard let matchData = match else {
                    // do not find match in the given length, stop now
                    return
                }
                
                self.readDataPrefix = rest
                //                self.delegate?.didRead(data: matchData, from: self)
                self.local.write(matchData)
                
            } else {
                self.local.write(data)
                //                self.delegate?.didRead(data: data, from: self)
            }
        }
    }
    
    
    
    private func consumeReadData(_ data: Data?) -> Data? {
        defer {
            readDataPrefix = nil
        }
        
        if readDataPrefix == nil {
            return data
        }
        
        if data == nil {
            return readDataPrefix
        }
        
        var wholeData = readDataPrefix!
        wholeData.append(data!)
        return wholeData
    }
    
    
    //将数据写入远程
    private func send(data: Data) {
        writePending = true
        self.newRemote!.write(data) { error in
            self.queueCall {
                self.writePending = false
                
                guard error == nil else {
                    
                    self.disconnect()
                    return
                }
                
                //self.delegate?.didWrite(data: data, by: self)
                
                NSLog("数据已经写入远程")
                self.local.readData() // 远程写完 本地继续读
                self.checkStatus()
            }
        }
    }
    
    public func disconnect() {
        
        cancelled = true
        if newRemote == nil  || newRemote!.state == .cancelled {
            
        } else {
            closeAfterWriting = true
            checkStatus()
        }
    }
    
    private func checkStatus() {
        if closeAfterWriting && !writePending {
            newRemote?.cancel()
        }
    }

    
}







extension TCPConnection: ZPTCPConnectionDelegate {
    
    func connection(_ connection: ZPTCPConnection, didRead data: Data) {
        if data.count > 0 {
            let str = String.init(data: data, encoding: .utf8)
            NSLog("wuplyer TCP---- TCP接受 Tunnel 的数据:\(str ?? "")")
        }
        //远程soc
//        self.remote.write(data, withTimeout: 5, tag: 0)
        
        self.write(data: data)
        self.readData()
        
    }
    
    func connection(_ connection: ZPTCPConnection, didWriteData length: UInt16, sendBuf isEmpty: Bool) {
        NSLog("wuplyer TCP---- 将数据写入应用之后")
        if isEmpty {
//            self.remote.readData(withTimeout: -1, buffer: nil, bufferOffset: 0, maxLength: UInt(UINT16_MAX / 2), tag: 0)
//            self.readData()
             self.readData()
        }
        
//        self.remote.readData(withTimeout: -1, tag: 0)
        
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

//extension TCPConnection: GCDAsyncSocketDelegate {
//
//    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
//        /* session status */
//        self.sessionModel.status = .active
//        self.local.readData()
////        self.remote.readData(withTimeout: -1, buffer: nil, bufferOffset: 0, maxLength: UInt(UINT16_MAX / 2), tag: 0)
//         self.remote.readData(withTimeout: -1, tag: 0)
//    }
//
//    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
//
//        let str = String.init(data: data, encoding: .utf8)
//        NSLog("wuplyer TCP---- TCP接受远程的数据:\(str ?? "")")
//
//        self.local.write(data)
//        self.remote.readData(withTimeout: -1, tag: tag)
//    }
//
//    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
//        self.local.readData()
//        self.remote.readData( withTimeout: 5, tag:tag)
//    }
//
//    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
//        self.close(with: "Remote: \(String(describing: err))")
//    }
//
//}
