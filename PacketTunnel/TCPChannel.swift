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

public enum TCPChannelStatus: CustomStringConvertible {
        
        case invalid, readingRequest, waitingToBeReady, forwarding, closing, closed
        
        public var description: String {
            switch self {
            case .invalid:
                return "invalid"
            case .readingRequest:
                return "reading request"
            case .waitingToBeReady:
                return "waiting to be ready"
            case .forwarding:
                return "forwarding"
            case .closing:
                return "closing"
            case .closed:
                return "closed"
            }
        }
    }

protocol TCPChannelDelegate :class{
     func tunnelDidClose(_ tunnel: TCPChannel)
}

class TCPChannel: NSObject {
    
    var proxySocket: ProxySocket
    
     var adapterSocket: AdapterSocket?
    
    /// The delegate instance.
    weak var delegate: TCPChannelDelegate?
       
     
       /// Indicating how many socket is ready to forward data.
       private var readySignal = 0
       
       /// If the tunnel is closed, i.e., proxy socket and adapter socket are both disconnected.
       var isClosed: Bool {
           return proxySocket.isDisconnected && (adapterSocket?.isDisconnected ?? true)
       }
       
       fileprivate var _cancelled: Bool = false
       fileprivate var _stopForwarding = false
       public var isCancelled: Bool {
           return _cancelled
       }
       
       fileprivate var _status: TCPChannelStatus = .invalid
       public var status: TCPChannelStatus {
           return _status
       }
       
       public var statusDescription: String {
           return status.description
       }
       
       override public var description: String {
           if let adapterSocket = adapterSocket {
               return "<TCPChannel proxySocket:\(proxySocket) adapterSocket:\(adapterSocket)>"
           } else {
               return "<TCPChannel proxySocket:\(proxySocket)>"
           }
       }
       
       init(proxySocket: ProxySocket) {
           self.proxySocket = proxySocket
           super.init()
        self.proxySocket.delegate = self as? SocketDelegate
       }
       
       /**
        Start running the tunnel.
        */
       func openTunnel() {
           guard !self.isCancelled else {
               return
           }
           
           self.proxySocket.openSocket()
           self._status = .readingRequest
          
       }
       
       /**
        Close the tunnel elegantly.
        */
       func close() {
         
           guard !self.isCancelled else {
               return
           }
           
           self._cancelled = true
           self._status = .closing
           
           if !self.proxySocket.isDisconnected {
               self.proxySocket.disconnect()
           }
           if let adapterSocket = self.adapterSocket {
               if !adapterSocket.isDisconnected {
                   adapterSocket.disconnect()
               }
           }
       }
       
       /// Close the tunnel immediately.
       ///
       /// - note: This method is thread-safe.
       func forceClose() {
    
           guard !self.isCancelled else {
               return
           }
           
           self._cancelled = true
           self._status = .closing
           self._stopForwarding = true
           
           if !self.proxySocket.isDisconnected {
               self.proxySocket.forceDisconnect()
           }
           if let adapterSocket = self.adapterSocket {
               if !adapterSocket.isDisconnected {
                   adapterSocket.forceDisconnect()
               }
           }
       }
       
       public func didReceive(session: ConnectSession, from: ProxySocket) {
           guard !isCancelled else {
               return
           }
           
           _status = .waitingToBeReady
           
           if !session.isIP() {
               _ = Resolver.resolve(hostname: session.host, timeout: Opt.DNSTimeout) { [weak self] resolver, err in
                   QueueFactory.getQueue().async {
                       if err != nil {
                           session.ipAddress = ""
                       } else {
                           session.ipAddress = (resolver?.ipv4Result.first)!
                       }
                       self?.openAdapter(for: session)
                   }
               }
           } else {
               session.ipAddress = session.host
               openAdapter(for: session)
           }
       }
       
       fileprivate func openAdapter(for session: ConnectSession) {
           guard !isCancelled else {
               return
           }
        adapterSocket =  DirectAdapter()
        guard adapterSocket == adapterSocket else {
            return
        }
        adapterSocket?.socket = RawSocketFactory.getRawSocket()
        adapterSocket!.delegate = self as? SocketDelegate
        adapterSocket!.openSocketWith(session: session)
       }
       
       public func didBecomeReadyToForwardWith(socket: SocketProtocol) {
           guard !isCancelled else {
               return
           }
           
           readySignal += 1
        
           defer {
               if let socket = socket as? AdapterSocket {
                   proxySocket.respondTo(adapter: socket)
               }
           }
           if readySignal == 2 {
               _status = .forwarding
               proxySocket.readData()
               adapterSocket?.readData()
           }
       }
       
       public func didDisconnectWith(socket: SocketProtocol) {
           if !isCancelled {
               _stopForwarding = true
               close()
           }
           checkStatus()
       }
       
       
       //从adapter 接收到数据
       public func didRead(data: Data, from socket: SocketProtocol) {
        
        if socket is ProxySocket {
             
               guard !isCancelled else {
                   return
               }
               adapterSocket!.write(data: data)
           } else if socket is AdapterSocket {
              
               guard !isCancelled else {
                   return
               }
               proxySocket.write(data: data)
           }
       }
       
       public func didWrite(data: Data?, by socket: SocketProtocol) {
        if socket is ProxySocket {
               guard !isCancelled else {
                   return
               }
               QueueFactory.getQueue().asyncAfter(deadline: DispatchTime.now() + DispatchTimeInterval.microseconds(Opt.forwardReadInterval)) { [weak self] in
                   self?.adapterSocket?.readData()
               }
        } else if socket is AdapterSocket {
             
               guard !isCancelled else {
                   return
               }
               
               proxySocket.readData()
           }
       }
       
       public func didConnectWith(adapterSocket: AdapterSocket) {
           guard !isCancelled else {
               return
           }
           
         
       }
       
       public func updateAdapterWith(newAdapter: AdapterSocket) {
           guard !isCancelled else {
               return
           }
        
           adapterSocket = newAdapter
           adapterSocket?.delegate = self as? SocketDelegate
       }
       
       fileprivate func checkStatus() {
           if isClosed {
               _status = .closed
               delegate?.tunnelDidClose(self)
               delegate = nil
           }
       }
    
}

