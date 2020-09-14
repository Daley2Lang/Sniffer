import Foundation

/// 该规则将主机域与预定义条件列表匹配。
open class DomainListRule: Rule {
    public enum MatchCriterion {
        case regex(NSRegularExpression), prefix(String), suffix(String), keyword(String), complete(String)

        func match(_ domain: String) -> Bool {
            switch self {
            case .regex(let regex):
                return regex.firstMatch(in: domain, options: [], range: NSRange(location: 0, length: domain.utf8.count)) != nil
            case .prefix(let prefix):
                return domain.hasPrefix(prefix)
            case .suffix(let suffix):
                return domain.hasSuffix(suffix)
            case .keyword(let keyword):
                return domain.contains(keyword)
            case .complete(let match):
                return domain == match
            }
        }
    }

    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<DomainListRule>"
    }

    /// The list of criteria to match to.
    open var matchCriteria: [MatchCriterion] = []

    /**
     创建一个新的“ DomainListRule”实例。

     -参数adapterFactory：用于在需要时构建相应适配器的工厂。
     -参数标准：要匹配的标准列表。
     */
    public init(adapterFactory: AdapterFactory, criteria: [MatchCriterion]) {
        self.adapterFactory = adapterFactory
        self.matchCriteria = criteria
    }

    /**
     将DNS请求与此规则匹配。
     -参数会话：要匹配的DNS会话。
     -参数类型：可用的信息类型。
     -返回：匹配结果。
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        if matchDomain(session.requestMessage.queries.first!.name) {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .real
            }
            return .fake
        }
        return .pass
    }

    /**
     将连接会话与此规则匹配。
     -参数会话：连接会话以匹配。
     -返回：配置的适配器（如果匹配），如果不匹配，则返回“ nil”。
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        if matchDomain(session.host) {
            return adapterFactory
        }
        return nil
    }

    fileprivate func matchDomain(_ domain: String) -> Bool {
        for criterion in matchCriteria {
            if criterion.match(domain) {
                return true
            }
        }
        return false
    }
}
