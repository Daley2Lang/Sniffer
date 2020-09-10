import Foundation

///表示IP协议的端口号。
public struct Port: CustomStringConvertible, ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = UInt16

    fileprivate var inport: UInt16

    /**
     使用网络字节顺序的端口号初始化一个新实例。

     -参数portInNetworkOrder：网络字节顺序的端口号。

     -返回：无符号端口。
     */
    public init(portInNetworkOrder: UInt16) {
        self.inport = portInNetworkOrder
    }

    /**
     用端口号初始化一个新实例。

     -参数端口：端口号。

     -返回：无符号端口。
     */
    public init(port: UInt16) {
        self.init(portInNetworkOrder: NSSwapHostShortToBig(port))
    }

    public init(integerLiteral value: Port.IntegerLiteralType) {
        self.init(port: value)
    }

    /**
  使用网络字节顺序的数据初始化一个新实例。

     -参数bytesInNetworkOrder：网络字节顺序的端口数据。

     -返回：无符号端口。
     */
    public init(bytesInNetworkOrder: UnsafeRawPointer) {
        self.init(portInNetworkOrder: bytesInNetworkOrder.load(as: UInt16.self))
    }

    public var description: String {
        return "<Port \(value)>"
    }

    /// The port number.
    public var value: UInt16 {
        return NSSwapBigShortToHost(inport)
    }

    public var valueInNetworkOrder: UInt16 {
        return inport
    }

    /**
 以**网络顺序**运行带有端口字节的块。

     -参数块：要运行的块。

     -返回：块返回的值。
     */
    public mutating func withUnsafeBufferPointer<T>(_ block: (UnsafeRawBufferPointer) -> T) -> T {
        return withUnsafeBytes(of: &inport) {
            return block($0)
        }
    }
}

public func == (left: Port, right: Port) -> Bool {
    return left.valueInNetworkOrder == right.valueInNetworkOrder
}

extension Port: Hashable {}
