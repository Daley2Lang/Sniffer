import Foundation

struct ConnectInfo {
    let sourceAddress: IPAddress
    let sourcePort: Port
    let destinationAddress: IPAddress
    let destinationPort: Port
}

extension ConnectInfo: Hashable {}

func == (left: ConnectInfo, right: ConnectInfo) -> Bool {
    return left.destinationAddress == right.destinationAddress &&
        left.destinationPort == right.destinationPort &&
        left.sourceAddress == right.sourceAddress &&
        left.sourcePort == right.sourcePort
}


/// This stack tranmits UDP packets directly.
public class UDPDirectStack: IPStackProtocol {
    fileprivate var activeSockets: [ConnectInfo: NWUDPSocket] = [:]
    public var outputFunc: (([Data], [NSNumber]) -> Void)!
    fileprivate let queue: DispatchQueue = DispatchQueue(label: "NEKit.UDPDirectStack.SocketArrayQueue", attributes: [])

    public init() {}
    
    
    //MARK:IPStackProtocol 协议实现
    /**
     将数据包输入到堆栈中。
     -注意：到目前为止，仅处理IPv4 UDP数据包。
     -参数包：IP包。
     -参数版本：IP数据包的版本，即AF_INET，AF_INET6。
     -返回：如果堆栈在此数据包中接受。如果数据包被接受，则其他IP堆栈将不会对其进行处理。
     */
    public func input(packet: Data, version: NSNumber?) -> Bool {
        if let version = version {
            // 处理不了IPV6
            if version.int32Value == AF_INET6 {
                return false
            }
        }
        if IPPacket.peekProtocol(packet) == .udp {
            input(packet)
            return true
        }
        return false
    }
    
    public func start() {
        
    }
    public func stop() {
        queue.async {
            for socket in self.activeSockets.values {
                socket.disconnect()
            }
            self.activeSockets = [:]
        }
    }

    
    fileprivate func input(_ packetData: Data) {
        guard let packet = IPPacket(packetData: packetData) else {
            return
        }

        guard let (_, socket) = findOrCreateSocketForPacket(packet) else {
            return
        }

        // swiftlint:disable:next force_cast
        let payload = (packet.protocolParser as! UDPProtocolParser).payload
        socket.write(data: payload!)
    }

    fileprivate func findSocket(connectInfo: ConnectInfo?, socket: NWUDPSocket?) -> (ConnectInfo, NWUDPSocket)? {
        var result: (ConnectInfo, NWUDPSocket)?

        queue.sync {
            if connectInfo != nil {
                guard let sock = self.activeSockets[connectInfo!] else {
                    result = nil
                    return
                }
                result = (connectInfo!, sock)
                return
            }

            guard let socket = socket else {
                result = nil
                return
            }

            guard let index = self.activeSockets.firstIndex(where: { _, sock in
                return socket === sock
            }) else {
                result = nil
                return
            }

            result = self.activeSockets[index]
        }
        return result
    }

    fileprivate func findOrCreateSocketForPacket(_ packet: IPPacket) -> (ConnectInfo, NWUDPSocket)? {
        // swiftlint:disable:next force_cast
        let udpParser = packet.protocolParser as! UDPProtocolParser
        let connectInfo = ConnectInfo(sourceAddress: packet.sourceAddress, sourcePort: udpParser.sourcePort, destinationAddress: packet.destinationAddress, destinationPort: udpParser.destinationPort)

        if let (_, socket) = findSocket(connectInfo: connectInfo, socket: nil) {
            return (connectInfo, socket)
        }

        guard let session = ConnectSession(ipAddress: connectInfo.destinationAddress, port: connectInfo.destinationPort) else {
            return nil
        }

        guard let udpSocket = NWUDPSocket(host: session.host, port: session.port) else {
            return nil
        }

        udpSocket.delegate = self

        queue.sync {
            self.activeSockets[connectInfo] = udpSocket
        }
        return (connectInfo, udpSocket)
    }

 
   
}

extension UDPDirectStack : NWUDPSocketDelegate{
    public func didReceive(data: Data, from: NWUDPSocket) {
         guard let (connectInfo, _) = findSocket(connectInfo: nil, socket: from) else {
             return
         }

         let packet = IPPacket()
         packet.sourceAddress = connectInfo.destinationAddress
         packet.destinationAddress = connectInfo.sourceAddress
         let udpParser = UDPProtocolParser()
         udpParser.sourcePort = connectInfo.destinationPort
         udpParser.destinationPort = connectInfo.sourcePort
         udpParser.payload = data
         packet.protocolParser = udpParser
         packet.transportProtocol = .udp
         packet.buildPacket()

         outputFunc([packet.packetData], [NSNumber(value: AF_INET as Int32)])
     }
     
    public func didCancel(socket: NWUDPSocket) {
           guard let (info, _) = findSocket(connectInfo: nil, socket: socket) else {
               return
           }
           
           activeSockets.removeValue(forKey: info)
       }
}
