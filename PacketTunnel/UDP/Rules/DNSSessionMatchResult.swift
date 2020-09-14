import Foundation

/**
 规则与DNS请求匹配的结果。
 -真实：请求符合规则，并且可以使用真实IP地址进行连接。
 -伪造：请求符合规则，但是当使用IP地址而不是主机域触发更高的连接时，我们需要标识此会话。
 -未知：匹配类型为“ DNSSessionMatchType.Domain”，但规则需要解析的IP地址。
 -通过：此规则与请求不匹配。
 */
public enum DNSSessionMatchResult {
    case real, fake, unknown, pass
}
