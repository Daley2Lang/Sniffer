import Foundation

/// 类管理规则。
open class RuleManager {
    ///当前使用的`RuleManager`，一次只能使用一个管理器。
    ///-注意：应在任何DNS或连接会话之前进行设置。
    public static var currentManager: RuleManager = RuleManager(fromRules: [], appendDirect: true)
    /// The rule list.
    var rules: [Rule] = []
    open var observer: Observer<RuleMatchEvent>?

    /**
     根据给定的规则创建一个新的“ RuleManager”。
     -参数规则：规则。
     -参数appendDirect：是否在列表末尾附加DirectRule，以便任何请求与任何规则都不匹配直接进行。
     */
    public init(fromRules rules: [Rule], appendDirect: Bool = false) {
        self.rules = rules

        if appendDirect || self.rules.count == 0 {
            self.rules.append(DirectRule())
        }

        observer = ObserverFactory.currentFactory?.getObserverForRuleManager(self)
    }

    /**
     将DNS请求与所有规则匹配。
     -参数会话：要匹配的DNS会话。
     -参数类型：可用的信息类型。
     */
    func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) {
        for (i, rule) in rules[session.indexToMatch..<rules.count].enumerated() {
            let result = rule.matchDNS(session, type: type)

            observer?.signal(.dnsRuleMatched(session, rule: rule, type: type, result: result))

            switch result {
            case .fake, .real, .unknown:
                session.matchedRule = rule
                session.matchResult = result
                session.indexToMatch = i + session.indexToMatch // add the offset
                return
            case .pass:
                break
            }
        }
    }

    /**
     将连接会话与所有规则匹配。
     -参数会话：连接会话以匹配。
     -返回：匹配的已配置适配器。
     */
    func match(_ session: ConnectSession) -> AdapterFactory! {
        if session.matchedRule != nil {
            observer?.signal(.ruleMatched(session, rule: session.matchedRule!))
            return session.matchedRule!.match(session)
        }

        for rule in rules {
            if let adapterFactory = rule.match(session) {
                observer?.signal(.ruleMatched(session, rule: rule))

                session.matchedRule = rule
                return adapterFactory
            } else {
                observer?.signal(.ruleDidNotMatch(session, rule: rule))
            }
        }
        return nil // this should never happens
    }
}
