import Foundation

/// The rule matches the ip of the target hsot to a list of IP ranges.
open class IPRangeListRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<IPRangeList>"
    }

    /// The list of regular expressions to match to.
    open var ranges: [IPRange] = []

    /**
     创建一个新的IPRangeListRule实例。
     -参数adapterFactory：用于在需要时构建相应适配器的工厂。
     -参数范围：要匹配的IP范围列表。 IP范围以CIDR形式（“ 127.0.0.1/8”）或范围形式（“ 127.0.0.1 + 16777216”）表示。
     -throws：解析IP范围时出错。
     */
    public init(adapterFactory: AdapterFactory, ranges: [String]) throws {
        self.adapterFactory = adapterFactory
        self.ranges = try ranges.map {
            let range = try IPRange(withString: $0)
            return range
        }
    }

    /**
     将DNS请求与此规则匹配。
     -参数会话：要匹配的DNS会话。
     -参数类型：可用的信息类型。
     -返回：匹配结果。
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        guard type == .ip else {
            return .unknown
        }

        // Probably we should match all answers?
        guard let ip = session.realIP else {
            return .pass
        }

        for range in ranges {
            if range.contains(ip: ip) {
                return .fake
            }
        }
        return .pass
    }

    /**
     将连接会话与此规则匹配。
     -参数会话：连接会话以匹配。
     -返回：配置的适配器（如果匹配），如果不匹配，则返回“ nil”。
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        guard let ip = IPAddress(fromString: session.ipAddress) else {
            return nil
        }

        for range in ranges {
            if range.contains(ip: ip) {
                return adapterFactory
            }
        }
        return nil
    }
}
