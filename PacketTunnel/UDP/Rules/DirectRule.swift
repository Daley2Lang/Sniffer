import Foundation

///规则匹配每个请求并返回直接适配器。
///
///等价于使用`DirectAdapterFactory`创建`AllRule`。
open class DirectRule: AllRule {
    open override var description: String {
        return "<DirectRule>"
    }
    /**
     Create a new `DirectRule` instance.
     */
    public init() {
        super.init(adapterFactory: DirectAdapterFactory())
    }
}
