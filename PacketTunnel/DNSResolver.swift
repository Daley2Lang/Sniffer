import Foundation

public protocol DNSResolverProtocol: class {
    var delegate: DNSResolverDelegate? { get set }
    func resolve(session: DNSSession)
    func stop()
}

public protocol DNSResolverDelegate: class {
    func didReceive(rawResponse: Data)
}

open class UDPDNSResolver: DNSResolverProtocol {
    let socket: NWUDPSocket
    public weak var delegate: DNSResolverDelegate?
    
    // eg:114.114.114.114
    public init(address: IPAddress, port: Port) {
        socket = NWUDPSocket(host: address.presentation, port: Int(port.value))!
        socket.delegate = self
    }
    
    //MARK: DNSResolverProtocol 实现
    public func resolve(session: DNSSession) {
        socket.write(data: session.requestMessage.payload)
    }
    
    public func stop() {
        socket.disconnect()
    }
    
}


extension UDPDNSResolver : NWUDPSocketDelegate{
    
    public func didReceive(data: Data, from: NWUDPSocket) {
        let str = String.init(data: data, encoding: .ascii)
        NSLog("wuplyer ----  DNS 服务端信息 收到回应信息：\(String(describing: str)) ,回调给DNSSever")
        delegate?.didReceive(rawResponse: data)
    }
    
    public func didCancel(socket: NWUDPSocket) {
        
    }
}
