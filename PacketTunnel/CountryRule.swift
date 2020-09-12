import Foundation


/// The rule matches the session based on the geographical location of the corresponding IP address.
/// 该规则基于相应IP地址的地理位置来匹配会话。
open class CountryRule: Rule {
    fileprivate let adapterFactory: AdapterFactory
    ///国家的ISO代码。
    public let countryCode: String
    ///规则应匹配与国家/地区不匹配的会话。
    public let match: Bool

    open override var description: String {
        return "<CountryRule countryCode:\(countryCode) match:\(match)>"
    }

    /**
     创建一个新的“ CountryRule”实例。
     -参数countryCode：国家/地区的ISO代码。
     -参数匹配：规则应匹配与国家/地区不匹配的会话。
     -参数adapterFactory：用于在需要时构建相应适配器的工厂。
     */
//     let chinaRule = CountryRule(countryCode: "CN", match: true, adapterFactory: directAdapterFactory)
    public init(countryCode: String, match: Bool, adapterFactory: AdapterFactory) {
        self.countryCode = countryCode
        self.match = match
        self.adapterFactory = adapterFactory
        super.init()
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

        if (session.countryCode != countryCode) != match {
            if let _ = adapterFactory as? DirectAdapterFactory {
                return .real
            } else {
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
        if (session.country != countryCode) != match {
            return adapterFactory
        }
        return nil
    }
}
