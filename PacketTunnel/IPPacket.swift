import Foundation

public enum IPVersion: UInt8 {
    case iPv4 = 4, iPv6 = 6
}

public enum TransportProtocol: UInt8 {
    case icmp = 1, tcp = 6, udp = 17
}

///处理和构建IP数据包的类。
///-注意：到目前为止，仅支持IPv4。
open class IPPacket {
    
    /// 当前ip包 协议版本
    open var version: IPVersion = .iPv4
    
    /// 包头长度 IP数据包首部 20字节，UDP 数据包首部8字节
    open var headerLength: UInt8 = 20
    
    ///包含IP数据包的DSCP和ECN。
    ///-注意：由于我们无法使用NetworkExtension发送自定义IP数据包，因此这是无用的，只是被忽略了。
    open var tos: UInt8 = 0
    
    ///这应该是数据报的长度。
    ///由于NEPacketTunnelFlow已经为我们处理了此值，因此不会从标头中读取该值。
    open var totalLength: UInt16 {
        return UInt16(packetData.count)
    }
    
    ///当前数据包的标识。
    ///-注意：由于我们不支持片段，因此将忽略该片段，并且始终为零。
    ///-注意：从理论上讲，这应该是一个递增的数字。它可能会实现。
    var identification: UInt16 = 0
    
    ///当前数据包的偏移量。
    ///
    ///-注意：由于我们不支持片段，因此将忽略该片段，并且始终为零。
    var offset: UInt16 = 0
    
    /// TTL of the packet 。生存时间 每转发一次路由减一
    var TTL: UInt8 = 64
    
    /// 源ip.
    var sourceAddress: IPAddress!
    
    /// 目标ip
    var destinationAddress: IPAddress!
    
    /// 数据包的传输协议。
    var transportProtocol: TransportProtocol!
    
    ///解析器解析IP数据包中的有效负载。 / /DNS 是udp数据包 UDPProtocolParser 
    var protocolParser: TransportProtocolParserProtocol!
    
    ///代表数据包的数据。
    var packetData: Data!
    
    /**
     Initailize a new instance to build IP packet.
     */
    init() {}
    
    /**
     Initailize an `IPPacket` with data.
     - parameter packetData: 包含整个数据包的数据。
     */
    init?(packetData: Data) {
        // no need to validate the packet.无需验证数据包。
        
        self.packetData = packetData
        
        let scanner = BinaryDataScanner(data: packetData, littleEndian: false)
        
        let vhl = scanner.readByte()!
        guard let v = IPVersion(rawValue: vhl >> 4) else {
            NSLog("得到了未知的IP数据包版本 \(vhl >> 4)")
            return nil
        }
        version = v
        headerLength = vhl & 0x0F * 4
        
        guard packetData.count >= Int(headerLength) else {
            return nil
        }
        
        tos = scanner.readByte()!
        
        guard totalLength == scanner.read16()! else {
            NSLog("数据包长度与标头不匹配。")
            return nil
        }
        
        identification = scanner.read16()!
        offset = scanner.read16()!
        TTL = scanner.readByte()!
        
        guard let proto = TransportProtocol(rawValue: scanner.readByte()!) else {
            NSLog("获取不支持的数据包协议。")
            return nil
        }
        transportProtocol = proto
        
        // ignore checksum
        _ = scanner.read16()!
        
        switch version {
        case .iPv4:
            sourceAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
            destinationAddress = IPAddress(ipv4InNetworkOrder: CFSwapInt32(scanner.read32()!))
        default:
            // IPv6 is not supported yet.
            NSLog("IPv6 is not supported yet.")
            return nil
        }
        
        switch transportProtocol! {
        case .udp:
            guard let parser = UDPProtocolParser(packetData: packetData, offset: Int(headerLength)) else {
                return nil
            }
            self.protocolParser = parser
        default:
            NSLog("无法解析类型的数据包头 \(String(describing: transportProtocol)) ")
            return nil
        }
    }
    
    
    /**
     在不解析整个数据包的情况下获取IP数据包的版本。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的版本。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekIPVersion(_ data: Data) -> IPVersion? {
        guard data.count >= 20 else {
            return nil
        }
        
        let version = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee >> 4
        return IPVersion(rawValue: version)
    }
    
    /**
     在不解析整个数据包的情况下获取IP数据包的协议。
     */
    public static func peekProtocol(_ data: Data) -> TransportProtocol? {
        guard data.count >= 20 else {
            return nil
        }
        
        //        TransportProtocol(rawValue: <#UInt8#>)
        //        (data as NSData).bytes.bindMemory(to: <#T##T.Type#>, capacity: <#T##Int#>) 将内存绑定到指定的类型，并返回指向该类型的指针
        //advanced   返回一个从该值偏移指定距离的值。 适用任何类型，int ，或者字节，指针 等等
        return TransportProtocol(rawValue: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).advanced(by: 9).pointee)
    }
    
    /**
     在不解析整个数据包的情况下获取IP数据包的源IP地址。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的源IP地址。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekSourceAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }
        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 12))
    }
    
    /**
     在不解析整个数据包的情况下获取IP数据包的目标IP地址。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的目标IP地址。如果解析数据包失败，则返回“ nil”。
     */
    public static func peekDestinationAddress(_ data: Data) -> IPAddress? {
        guard data.count >= 20 else {
            return nil
        }
        return IPAddress(fromBytesInNetworkOrder: (data as NSData).bytes.advanced(by: 16))
    }
    
    /**
     获取IP数据包的源端口，而不解析整个数据包。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的源IP地址。如果解析数据包失败，则返回“ nil”。
     -注意：仅TCP和UDP数据包具有端口字段。
     */
    public static func peekSourcePort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }
        
        guard proto == .tcp || proto == .udp else {
            return nil
        }
        
        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)
        
        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }
        
        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength))
    }
    
    /**
     在不解析整个数据包的情况下获取IP数据包的目标端口。
     -参数数据：包含整个IP数据包的数据。
     -返回：数据包的目标IP地址。如果解析数据包失败，则返回“ nil”。
     -注意：仅TCP和UDP数据包具有端口字段。
     */
    public static func peekDestinationPort(_ data: Data) -> Port? {
        guard let proto = peekProtocol(data) else {
            return nil
        }
        
        guard proto == .tcp || proto == .udp else {
            return nil
        }
        
        let headerLength = Int((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count).pointee & 0x0F * 4)
        
        // Make sure there are bytes for source and destination bytes.
        guard data.count > headerLength + 4 else {
            return nil
        }
        
        return Port(bytesInNetworkOrder: (data as NSData).bytes.advanced(by: headerLength + 2))
    }
    
    
    func computePseudoHeaderChecksum() -> UInt32 {
        var result: UInt32 = 0
        if let address = sourceAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        if let address = destinationAddress {
            result += address.UInt32InNetworkOrder! >> 16 + address.UInt32InNetworkOrder! & 0xFFFF
        }
        result += UInt32(transportProtocol.rawValue) << 8
        result += CFSwapInt32(UInt32(protocolParser.bytesLength))
        return result
    }
    
    func buildPacket() {
        packetData = NSMutableData(length: Int(headerLength) + protocolParser.bytesLength) as Data?
        
        // 构建包头
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(tos, at: 1)
        setPayloadWithUInt16(totalLength, at: 2)
        setPayloadWithUInt16(identification, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(TTL, at: 8)
        setPayloadWithUInt8(transportProtocol.rawValue, at: 9)
        // 清除校验字节
        resetPayloadAt(10, length: 2)
        setPayloadWithUInt32(sourceAddress.UInt32InNetworkOrder!, at: 12, swap: false)
        setPayloadWithUInt32(destinationAddress.UInt32InNetworkOrder!, at: 16, swap: false)
        
        // let TCP or UDP packet build
        protocolParser.packetData = packetData
        protocolParser.offset = Int(headerLength)
        protocolParser.buildSegment(computePseudoHeaderChecksum())
        packetData = protocolParser.packetData
        
        setPayloadWithUInt16(Checksum.computeChecksum(packetData, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }
    
    func setPayloadWithUInt8(_ value: UInt8, at: Int) {
        var v = value
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+1, with: $0)
        }
    }
    
    func setPayloadWithUInt16(_ value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+2, with: $0)
        }
    }
    
    func setPayloadWithUInt32(_ value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+4, with: $0)
        }
    }
    
    func setPayloadWithData(_ data: Data, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.count - from
        }
        packetData.replaceSubrange(at..<at+length!, with: data)
    }
    
    func resetPayloadAt(_ at: Int, length: Int) {
        packetData.resetBytes(in: at..<at+length)
    }
    
}
