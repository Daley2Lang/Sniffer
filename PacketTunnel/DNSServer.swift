import Foundation
import NetworkExtension


/// A DNS server designed as an `IPStackProtocol` implementation which works with TUN interface.
///
/// This class is thread-safe.
open class DNSServer:  IPStackProtocol {
    /// Current DNS server.
    ///
    /// - warning: 最多同时运行一台DNS服务器。如果DNS服务器注册到`TUNInterface`，则也必须在此处设置它。
    public static var currentServer: DNSServer?

    /// The address of DNS server.
    let serverAddress: IPAddress

    /// The port of DNS server
    let serverPort: Port

    fileprivate let queue: DispatchQueue = QueueFactory.getQueue()
    fileprivate var fakeSessions: [IPAddress: DNSSession] = [:]
    fileprivate var pendingSessions: [UInt16: DNSSession] = [:]
    fileprivate let pool: IPPool?
    fileprivate var resolvers: [DNSResolverProtocol] = []

    open var outputFunc: (([Data], [NSNumber]) -> Void)!

    // 到目前为止，仅匹配A记录，所有其他记录应直接传递。
    fileprivate let matchedType = [DNSType.a]

    /**
     初始化DNS服务器
     -参数地址：服务器的IP地址。
     -参数端口：服务器的侦听端口。
     -参数fakeIPPool：假IP地址池。 如果不需要伪造IP，则设置为nil。
     */
    // 
    public init(address: IPAddress, port: Port, fakeIPPool: IPPool? = nil) {
        serverAddress = address
        serverPort = port
        pool = fakeIPPool
    }

    /**
     清理假IP。
     -参数地址：假IP地址。
     -参数延迟：假IP有效期为多长时间。
     */
    fileprivate func cleanUpFakeIP(_ address: IPAddress, after delay: Int) {
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            [weak self] in
            _ = self?.fakeSessions.removeValue(forKey: address)
            self?.pool?.release(ip: address)
        }
    }

    /**
     Clean up pending session.

     - parameter session: The pending session.
     - parameter delay:   How long before the pending session be cleaned up.
     */
    fileprivate func cleanUpPendingSession(_ session: DNSSession, after delay: Int) {
        queue.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
            [weak self] in
            _ = self?.pendingSessions.removeValue(forKey: session.requestMessage.transactionID)
        }
    }

    fileprivate func lookup(_ session: DNSSession) {
        guard shouldMatch(session) else {
            session.matchResult = .real
            lookupRemotely(session)
            return
        }
        
        RuleManager.currentManager.matchDNS(session, type: .domain)

        switch session.matchResult! {
        case .fake:
            guard setUpFakeIP(session) else {
                // 设置错误的IP失败，直接返回结果
                session.matchResult = .real
                lookupRemotely(session)
                return
            }
            outputSession(session)
        case .real, .unknown:
            lookupRemotely(session)
        default:
            NSLog("The rule match result should never be .Pass.")//规则匹配结果不应为.Pass。
        }
    }

    fileprivate func lookupRemotely(_ session: DNSSession) {
        pendingSessions[session.requestMessage.transactionID] = session
        cleanUpPendingSession(session, after: Opt.DNSPendingSessionLifeTime)
        sendQueryToRemote(session) //UDP 请求114.114.114.114
    }

    fileprivate func sendQueryToRemote(_ session: DNSSession) {
        for resolver in resolvers {
            resolver.resolve(session: session)
        }
    }

    //MARK: IPStackProtocol 实现
    /**
     将IP数据包输入到DNS服务器。
     -参数包：IP包。
     -参数版本：IP数据包的版本。
     -返回：如果数据包被此DNS服务器接收。
     */
    open func input(packet: Data, version: NSNumber?) -> Bool {
        
        guard IPPacket.peekProtocol(packet) == .udp else {
            return false
        }

        guard IPPacket.peekDestinationAddress(packet) == serverAddress else {
            return false
        }

        guard IPPacket.peekDestinationPort(packet) == serverPort else {
            return false
        }

        let desPort    =  IPPacket.peekDestinationPort(packet)
        let desiIP     = IPPacket.peekDestinationAddress(packet)
        
        let sourceIP   = IPPacket.peekSourceAddress(packet)
        let sourcePort = IPPacket.peekSourcePort(packet)
        
        
        NSLog("wuplyer ----  捕获到DNS UDP 源IP:\(String(describing: sourceIP))")
        NSLog("wuplyer ----  捕获到DNS UDP 源端口:\(String(describing: sourcePort))")
        NSLog("wuplyer ----  捕获到DNS UDP 目标IP:\(String(describing: desiIP))")
        NSLog("wuplyer ----  捕获到DNS UDP 目标端口:\(desPort ?? 9527)")
        
        guard let ipPacket = IPPacket(packetData: packet) else {
            return false
        }

        guard let session = DNSSession(packet: ipPacket) else {
            return false
        }

        queue.async {
            self.lookup(session)
        }
        return true
    }
    
    public func start() {
        
    }

    open func stop() {
        for resolver in resolvers {
            resolver.stop()
        }
        resolvers = []

        //用`dispatch_after`调度的块被忽略，因为它们很难被取消。但是不应该有任何后果，除了一些`IPAddress`es和`queue'将在以后发布之外，所有内容都会被发布。
    }

    fileprivate func outputSession(_ session: DNSSession) {
        guard let result = session.matchResult else {
            return
        }

        let udpParser = UDPProtocolParser()
        udpParser.sourcePort = serverPort
        // swiftlint:disable:next force_cast
        udpParser.destinationPort = (session.requestIPPacket!.protocolParser as! UDPProtocolParser).sourcePort
        switch result {
        case .real:
            udpParser.payload = session.realResponseMessage!.payload
        case .fake:
            let response = DNSMessage()
            response.transactionID = session.requestMessage.transactionID
            response.messageType = .response
            response.recursionAvailable = true
            // since we only support ipv4 as of now, it must be an answer of type A
            response.answers.append(DNSResource.ARecord(session.requestMessage.queries[0].name, TTL: UInt32(Opt.DNSFakeIPTTL), address: session.fakeIP!))
            session.expireAt = Date().addingTimeInterval(Double(Opt.DNSFakeIPTTL))
            guard response.buildMessage() else {
                NSLog("Failed to build DNS response.")
                return
            }

            udpParser.payload = response.payload
        default:
            return
        }
        let ipPacket = IPPacket()
        ipPacket.sourceAddress = serverAddress
        ipPacket.destinationAddress = session.requestIPPacket!.sourceAddress
        ipPacket.protocolParser = udpParser
        ipPacket.transportProtocol = .udp
        ipPacket.buildPacket()

        
         NSLog("wuplyer ----  将DNS 解析信息 返回")
        outputFunc([ipPacket.packetData], [NSNumber(value: AF_INET as Int32)])
    }

    fileprivate func shouldMatch(_ session: DNSSession) -> Bool {
        return matchedType.contains(session.requestMessage.type!)
    }

    func isFakeIP(_ ipAddress: IPAddress) -> Bool {
        return pool?.contains(ip: ipAddress) ?? false
    }

    func lookupFakeIP(_ address: IPAddress) -> DNSSession? {
        var session: DNSSession?
        QueueFactory.executeOnQueueSynchronizedly {
            session = self.fakeSessions[address]
        }
        return session
    }

    /**
     Add new DNS resolver to DNS server.
     - parameter resolver: The resolver to add.
     */
    open func registerResolver(_ resolver: DNSResolverProtocol) {
        resolver.delegate = self
        resolvers.append(resolver)
    }

    fileprivate func setUpFakeIP(_ session: DNSSession) -> Bool {

        guard let fakeIP = pool?.fetchIP() else {
            NSLog("Failed to get a fake IP.")
            return false
        }
        session.fakeIP = fakeIP
        fakeSessions[fakeIP] = session
        session.expireAt = Date().addingTimeInterval(TimeInterval(Opt.DNSFakeIPTTL))
        // keep the fake session for 2 TTL
        cleanUpFakeIP(fakeIP, after: Opt.DNSFakeIPTTL * 2)
        return true
    }

    
    

}

extension DNSServer :DNSResolverDelegate{
    open func didReceive(rawResponse: Data) {
        
        let str = String.init(data: rawResponse, encoding: .ascii)
        NSLog("wuplyer ----  DNS 服务端信息 收到回应信息：\(String(describing: str))")
        
        guard let message = DNSMessage(payload: rawResponse) else {
            NSLog("wuplyer ----  无法解析来自远程DNS服务器的响应。")
            return
        }
        
        queue.async {
            guard let session = self.pendingSessions.removeValue(forKey: message.transactionID) else {
                // 如果有多个DNS服务器或DNS服务器被劫持，这应该不是问题。 ？？？？
                NSLog("wuplyer ----  找不到响应的相应DNS会话")
                return
            }
            
            session.realResponseMessage = message
            
            session.realIP = message.resolvedIPv4Address
            
            if session.matchResult != .fake && session.matchResult != .real {
                RuleManager.currentManager.matchDNS(session, type: .ip)
            }
            
            switch session.matchResult! {
            case .fake:
                if !self.setUpFakeIP(session) {
                    // return real response
                    session.matchResult = .real
                }
                self.outputSession(session)
            case .real:
                self.outputSession(session)
            default:
                NSLog("wuplyer ---- 在IP模式下，规则匹配结果不得为.Pass或.Unknown。")
            }
        }
    }
}
