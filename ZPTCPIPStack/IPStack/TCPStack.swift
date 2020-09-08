import Foundation


///此类环绕tun2socks来构建仅TCP的IP堆栈。
  /*
 TCPStack处理TCP数据包，并将它们重新组合回TCP流，然后将其发送到proxyServer变量指定的代理服务器。你必须设置proxyServer在注册前TCPStack到TUNInterface。
 */
open class TCPStack: TSIPStackDelegate, IPStackProtocol {
    /// The `TCPStack` singleton instance.
    public static var stack: TCPStack {
        TSIPStack.stack.delegate = _stack
        TSIPStack.stack.processQueue = QueueFactory.getQueue()
        return _stack
    }
    fileprivate static let _stack: TCPStack = TCPStack()
    

    ///处理该堆栈接受的连接的代理服务器。

    ///-警告：必须在将TCPStack注册到TUNInterface之前进行设置。
    open weak var proxyServer: ProxyServer?
    
    ///当堆栈注册到某个接口时，将自动设置此项。
    open var outputFunc: (([Data], [NSNumber]) -> Void)! {
        get {
            return TSIPStack.stack.outputBlock
        }
        set {
            TSIPStack.stack.outputBlock = newValue
        }
    }
    
    /**
     Inistailize a new TCP stack.
     */
    fileprivate init() {
    }
    
    /**
     将数据包输入到堆栈中。
     -注意：由于稳定的lwip目前尚不支持ipv6，因此目前仅处理IPv4 TCP数据包。
     -参数包：IP包。
     -参数版本：IP数据包的版本，即AF_INET，AF_INET6。
     -返回：如果堆栈接收此数据包。如果数据包被接收，则其他IP堆栈将不会对其进行处理。
     */
    open func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            // we do not process IPv6 packets now
            if version.int32Value == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .tcp {
            TSIPStack.stack.received(packet: packet)
            return true
        }
        return false
    }
    
    public func start() {
        TSIPStack.stack.resumeTimer()
    }
    
    /**

=======
     停止TCP堆栈。
     调用此方法后，不应再引用该堆栈。使用“ TCPStack.stack”获取单例的新引用。

     */
    open func stop() {
        TSIPStack.stack.delegate = nil
        TSIPStack.stack.suspendTimer()
        proxyServer = nil
    }
    
    // MARK: TSIPStackDelegate 实现
    open func didAcceptTCPSocket(_ sock: TSTCPSocket) {
        NSLog("Accepted a new socket from IP stack.")
        let tunSocket = TUNTCPSocket(socket: sock)
        let proxySocket = DirectProxySocket(socket: tunSocket)
        self.proxyServer!.didAcceptNewSocket(proxySocket)
    }
}
