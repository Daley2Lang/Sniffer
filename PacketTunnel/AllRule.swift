import Foundation

/// 该规则匹配所有DNS和连接会话。
open class AllRule: Rule {
    fileprivate let adapterFactory: AdapterFactory

    open override var description: String {
        return "<AllRule>"
    }

    /**
     创建一个新的AllRule实例。

     -参数adapterFactory：用于在需要时构建相应适配器的工厂。
     */
    public init(adapterFactory: AdapterFactory) {
        self.adapterFactory = adapterFactory
        super.init()
    }

    /**
     将DNS会话与此规则匹配。
     -参数会话：要匹配的DNS会话。
     -参数类型：可用的信息类型。
     -返回：匹配结果。
     */
    override open func matchDNS(_ session: DNSSession, type: DNSSessionMatchType) -> DNSSessionMatchResult {
        // 当我们直接连接到远程设备时，仅返回真实IP
        if let _ = adapterFactory as? DirectAdapterFactory {
            return .real
        } else {
            return .fake
        }
    }

    /**
     将连接会话与此规则匹配。
     -参数会话：连接会话以匹配。
     -返回：配置的适配器。
     */
    override open func match(_ session: ConnectSession) -> AdapterFactory? {
        return adapterFactory
    }
}
