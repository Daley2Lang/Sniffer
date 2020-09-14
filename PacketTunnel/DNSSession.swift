import Foundation


open class DNSSession {
    public let requestMessage: DNSMessage
    var requestIPPacket: IPPacket?
    open var realIP: IPAddress?
    open var fakeIP: IPAddress?
    open var realResponseMessage: DNSMessage?
    var realResponseIPPacket: IPPacket?
    open var matchedRule: Rule?
    open var matchResult: DNSSessionMatchResult?
    var indexToMatch = 0
    var expireAt: Date?
    lazy var countryCode: String? = {
        [unowned self] in
        guard self.realIP != nil else {
            return nil
        }
        
//        return Utils.GeoIPLookup.Lookup(self.realIP!.presentation)
        return ""
    }()

    init?(message: DNSMessage) {
        guard message.messageType == .query else {
            NSLog("DNSSession can only be initailized by a DNS query.")//NSSession只能通过DNS查询初始化
            return nil
        }

        guard message.queries.count == 1 else {
            NSLog("Expecting the DNS query has exact one query entry.")//期望DNS查询具有确切的一个查询条目。
            return nil
        }

        requestMessage = message
    }

    convenience init?(packet: IPPacket) {
        guard let message = DNSMessage(payload: packet.protocolParser.payload) else {
            return nil
        }
        self.init(message: message)
        requestIPPacket = packet
    }
}

extension DNSSession: CustomStringConvertible {
    public var description: String {
        return "<\(type(of: self)) domain: \(self.requestMessage.queries.first!.name) realIP: \(String(describing: realIP)) fakeIP: \(String(describing: fakeIP))>"
    }
}
