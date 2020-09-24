//
//  NWUDPSocket.swift
//  PacketTunnel
//
//  Created by Qi Liu on 2020/9/10.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

import UIKit
import NetworkExtension


public protocol NWUDPSocketDelegate : class{
    //从套接字中接受数据
    func didReceive(data:Data,from:NWUDPSocket)
    //取消
    func didCancel(socket: NWUDPSocket)
}

public class NWUDPSocket: NSObject {
    
    private let session: NWUDPSession
    private var pendingWriteData : [Data] = []
    private var writing = false
    private let queue : DispatchQueue = DispatchQueue.init(label: "UDP")
    private let timer : DispatchSourceTimer
    private let timeOut :Int
    
    public weak var delegate : NWUDPSocketDelegate?
    ///上一次活动发生的时间。
    ///由于UDP不具有“关闭”语义，因此这可以指示超时。
    public var lastActive: Date = Date()
    
    public init?(host: String, port: Int, timeout: Int = Opt.UDPSocketActiveTimeout) {
        guard let udpSession = UDProxyServer.TunnelProvider?.createUDPSession(to: NWHostEndpoint(hostname: host, port: "\(port)"), from: nil) else {
            return nil
        }
        session  = udpSession
         NSLog("wuplyer ---- 创建 好系统 UDPSession socket")
        self.timeOut = timeout
        
        timer = DispatchSource.makeTimerSource(queue:queue)
        
        super.init()
        
        timer.schedule(deadline: DispatchTime.now(), repeating: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval), leeway: DispatchTimeInterval.seconds(Opt.UDPSocketActiveCheckInterval))
        
        timer.setEventHandler { [weak self] in
            self?.queueCall {
                self?.checkStatus()
            }
        }
        
        timer.resume()
        
        session.addObserver(self, forKeyPath:  #keyPath(NWUDPSession.state), options: [.new], context: nil)
        
        session.setReadHandler({ [ weak self ] datas, error in
            self?.queueCall {
                guard let sSelf = self else {
                    return
                }
                sSelf.updateActivityTimer()
                
                guard error == nil, let dataArray = datas else {
                    NSLog("wuplyer ---- 从远程服务器读取时出错. \(error?.localizedDescription ?? "链接重连")")
                    return
                }
                for data in dataArray {
                    sSelf.delegate?.didReceive(data: data, from: sSelf)
                }
            }
            }, maxDatagrams: 32)
        
    }
    
    //UDPSession 观察者处理
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "state" else {
            return
        }
        
        switch session.state {
        case .cancelled:
            queueCall {
                self.delegate?.didCancel(socket: self)
            }
        case .ready:
            checkWrite()
        default:
            break
            
        }
    }
    
    private func checkWrite() {
        updateActivityTimer()
        
        guard session.state == .ready else {
            return
        }
        
        guard !writing else {
            return
        }
        
        guard pendingWriteData.count > 0 else {
            return
        }
        
        writing = true
        session.writeMultipleDatagrams(self.pendingWriteData) {_ in
            self.queueCall {
                self.writing = false
                self.checkWrite()
            }
        }
        self.pendingWriteData.removeAll(keepingCapacity: true)
    }
    
    
    private func updateActivityTimer() {
        lastActive = Date()
    }
    
    
    private func queueCall(block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
    
    private func checkStatus() {
        if timeOut > 0 && Date().timeIntervalSince(lastActive) > TimeInterval(timeOut) {
            disconnect()
        }
    }
    
    
    //将数据发往远端
    public func write(data: Data) {
        pendingWriteData.append(data)
        checkWrite()
    }
    
    public func disconnect() {
        
    }
    
    deinit {
        session.removeObserver(self, forKeyPath: #keyPath(NWUDPSession.state))
    }
}
