import Foundation

open class AdapterSocket: NSObject, SocketProtocol, RawTCPSocketDelegate {
    open var session: ConnectSession!

    open override var description: String {
        return "<\(typeName) host:\(session.host) port:\(session.port))>"
    }

    internal var _cancelled = false
    public var isCancelled: Bool {
        return _cancelled
    }

    /**
     Connect to remote according to the `ConnectSession`.

     - parameter session: The connect session.
     */
    open func openSocketWith(session: ConnectSession) {
        guard !isCancelled else {
            return
        }

        self.session = session

        socket?.delegate = self
        _status = .connecting
    }

    deinit {
        socket?.delegate = nil
    }
    
    // MARK: SocketProtocol Implementation

    /// The underlying TCP socket transmitting data.
    open var socket: RawTCPSocketProtocol!

    /// The delegate instance.
    weak open var delegate: SocketDelegate?

    var _status: SocketStatus = .invalid
    /// The current connection status of the socket.
    public var status: SocketStatus {
        return _status
    }

    open var statusDescription: String {
        return "\(status)"
    }

    public init(observe: Bool = true) {
        super.init()

    }

    /**
     Read data from the socket.

     - warning: This should only be called after the last read is finished, i.e., `delegate?.didReadData()` is called.
     */
    open func readData() {
        guard !isCancelled else {
            return
        }

        socket?.readData()
    }

    /**
     Send data to remote.

     - parameter data: Data to send.
     - warning: This should only be called after the last write is finished, i.e., `delegate?.didWriteData()` is called.
     */
    open func write(data: Data) {
        guard !isCancelled else {
            return
        }

        socket?.write(data: data)
    }

    /**
     Disconnect the socket elegantly.
     */
    open func disconnect(becauseOf error: Error? = nil) {
        _status = .disconnecting
        _cancelled = true
        session.disconnected(becauseOf: error, by: .adapter)
      
        socket?.disconnect()
    }

    /**
     Disconnect the socket immediately.
     */
    open func forceDisconnect(becauseOf error: Error? = nil) {
        _status = .disconnecting
        _cancelled = true
        session.disconnected(becauseOf: error, by: .adapter)
   
        socket?.forceDisconnect()
    }

    // MARK: RawTCPSocketDelegate Protocol Implementation

    /**
     The socket did disconnect.

     - parameter socket: The socket which did disconnect.
     */
    open func didDisconnectWith(socket: RawTCPSocketProtocol) {
        _status = .closed
  
        delegate?.didDisconnectWith(socket: self)
    }

    /**
     The socket did read some data.

     - parameter data:    The data read from the socket.
     - parameter from:    The socket where the data is read from.
     */
    open func didRead(data: Data, from: RawTCPSocketProtocol) {
     
    }

    /**
     The socket did send some data.

     - parameter data:    The data which have been sent to remote (acknowledged). Note this may not be available since the data may be released to save memory.
     - parameter by:    The socket where the data is sent out.
     */
    open func didWrite(data: Data?, by: RawTCPSocketProtocol) {
     
    }

    /**
     The socket did connect to remote.

     - parameter socket: The connected socket.
     */
    open func didConnectWith(socket: RawTCPSocketProtocol) {
        _status = .established
        delegate?.didConnectWith(adapterSocket: self)
    }
}
