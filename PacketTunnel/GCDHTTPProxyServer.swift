import Foundation

public final class GCDHTTPProxyServer: GCDProxyServer {

    override public init(address: IPAddress?, port: Port) {
        super.init(address: address, port: port)
    }
    
    override public func handleNewGCDSocket(_ socket: GCDTCPSocket) {
        let proxySocket = HTTPProxySocket(socket: socket)
        didAcceptNewSocket(proxySocket)
    }
}
