import Foundation
import CocoaAsyncSocket

open class GCDProxyServer: WUProxyServer, GCDAsyncSocketDelegate {
    fileprivate var listenSocket: GCDAsyncSocket!

    override open func start() throws {
        
        
        
        
        try QueueFactory.executeOnQueueSynchronizedly {
            listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: QueueFactory.getQueue(), socketQueue: QueueFactory.getQueue())
            try listenSocket.accept(onInterface: address?.presentation, port: port.value)
            try super.start()
        }
        
        NSLog("wuplyer ---- http 代理服务器开启成功 ")
    }

    /**
     Stop the proxy server.
     */
    override open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            listenSocket?.setDelegate(nil, delegateQueue: nil)
            listenSocket?.disconnect()
            listenSocket = nil
            super.stop()
        }
    }

    open func handleNewGCDSocket(_ socket: GCDTCPSocket) {

    }

    open func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let gcdTCPSocket = GCDTCPSocket(socket: newSocket)
        handleNewGCDSocket(gcdTCPSocket)
    }

    public func newSocketQueueForConnection(fromAddress address: Data, on sock: GCDAsyncSocket) -> DispatchQueue? {
        return QueueFactory.getQueue()
    }
}
