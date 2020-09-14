import Foundation

/// 该规则定义了对DNS请求和连接会话的处理方式。
open class Rule: CustomStringConvertible {
    open var description: String {
        return "<Rule>"
    }

    /**
     Create a new rule.
     */
    public init() {
    }

    /**
     将DNS请求与此规则匹配。
     -参数会话：要匹配的DNS会话。
     -参数类型：可用的信息类型。
     -返回：匹配结果。
     */
    open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        return .real
    }

    /**
     将连接会话与此规则匹配。
     -参数会话：连接会话以匹配。
     -返回：配置的适配器（如果匹配），如果不匹配，则返回“ nil”。
     */
    open func match(_ session: ConnectSession) -> AdapterFactory? {
        return nil
    }
}
