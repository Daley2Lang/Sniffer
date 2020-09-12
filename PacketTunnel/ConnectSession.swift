import Foundation

///在一个连接会话中表示所有信息。
public final class ConnectSession {
    public enum EventSourceEnum {
        case proxy, adapter, tunnel
    }
    
    ///请求的主机。
    ///
    ///这是请求中收到的主机。 可以是域，真实IP或伪IP。
    public let requestedHost: String
    
   ///此会话的真正主机。
    ///
    ///如果会话没有主机域，则`host == requestedHost`。
    ///否则，如果“ fakeIPEnabled”为“ true”，则在DNS服务器中查找请求的IP地址，以查看其是否与域相对应。
    ///除非有充分的理由不这样做，否则任何套接字应该直接基于此连接。
    public var host: String
    
    /// The requested port.
    public let port: Int
    
    /// The rule to use to connect to remote. 用于连接到远程的规则。
    public var matchedRule: Rule?
    
    /// Whether If the `requestedHost` is an IP address. 是否`requestedHost`是IP地址。
    public let fakeIPEnabled: Bool
    
    public var error: Error?
    public var errorSource: EventSourceEnum?
    
    public var disconnectedBy: EventSourceEnum?
    
  ///解析的IP地址。
    ///
    ///-注意：这将始终是真实IP地址。
    public lazy var ipAddress: String = {
        [unowned self] in
        if self.isIP() {
            return self.host
        } else {
            let ip = Utils.DNS.resolve(self.host)
            
            guard self.fakeIPEnabled else {
                return ip
            }
            
            guard let dnsServer = DNSServer.currentServer else {
                return ip
            }
            
            guard let address = IPAddress(fromString: ip) else {
                return ip
            }
            
            guard dnsServer.isFakeIP(address) else {
                return ip
            }
            
            guard let session = dnsServer.lookupFakeIP(address) else {
                return ip
            }
            
            return session.realIP?.presentation ?? ""
        }
        }()
    
    /// The location of the host.
    public lazy var country: String = {
        [unowned self] in
        guard let c = Utils.GeoIPLookup.Lookup(self.ipAddress) else {
            return ""
        }
        return c
        }()
    
    public init?(host: String, port: Int, fakeIPEnabled: Bool = true) {
        self.requestedHost = host
        self.port = port
        
        self.fakeIPEnabled = fakeIPEnabled
        
        self.host = host
        if fakeIPEnabled {
            guard lookupRealIP() else {
                return nil
            }
        }
    }
    
    public convenience init?(ipAddress: IPAddress, port: Port, fakeIPEnabled: Bool = true) {
        self.init(host: ipAddress.presentation, port: Int(port.value), fakeIPEnabled: fakeIPEnabled)
    }
    
    func disconnected(becauseOf error: Error? = nil, by source: EventSourceEnum) {
        if disconnectedBy == nil {
            self.error = error
            if error != nil {
                errorSource = source
            }
            disconnectedBy = source
        }
    }
    
    fileprivate func lookupRealIP() -> Bool {
        /// 如果设置了自定义DNS服务器。
        guard let dnsServer = DNSServer.currentServer else {
            return true
        }
        
        // Only IPv4 is supported as of now.
        guard isIPv4() else {
            return true
        }
        
        let address = IPAddress(fromString: requestedHost)!
        guard dnsServer.isFakeIP(address) else {
            return true
        }
        
        // Look up fake IP reversely should never fail.
        guard let session = dnsServer.lookupFakeIP(address) else {
            return false
        }
        
        host = session.requestMessage.queries[0].name
        ipAddress = session.realIP?.presentation ?? ""
        matchedRule = session.matchedRule
        
        if session.countryCode != nil {
            country = session.countryCode!
        }
        return true
    }
    
    public func isIPv4() -> Bool {
        return Utils.IP.isIPv4(host)
    }
    
    public func isIPv6() -> Bool {
        return Utils.IP.isIPv6(host)
    }
    
    public func isIP() -> Bool {
        return isIPv4() || isIPv6()
    }
}

extension ConnectSession: CustomStringConvertible {
    public var description: String {
        if requestedHost != host {
            return "<\(type(of: self)) host:\(host) port:\(port) requestedHost:\(requestedHost)>"
        } else {
            return "<\(type(of: self)) host:\(host) port:\(port)>"
        }
    }
}
