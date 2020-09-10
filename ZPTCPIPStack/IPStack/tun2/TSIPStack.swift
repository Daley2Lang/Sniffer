import Foundation


/// 开发人员应执行的委托，以处理连接新的TCP套接字时的处理方法。
public protocol TSIPStackDelegate: class {
    /**
    接受新的TCP套接字。 这意味着我们收到了一个包含SYN信号的新TCP数据包。
     
      -参数sock：套接字对象。
     */
    func didAcceptTCPSocket(_ sock: TSTCPSocket)
}

func tcpAcceptFn(_ arg: UnsafeMutableRawPointer?, pcb: UnsafeMutablePointer<tcp_pcb>?, error: err_t) -> err_t {
    return TSIPStack.stack.didAcceptTCPSocket(pcb!, error: error)
}

func outputPCB(_ interface: UnsafeMutablePointer<netif>?, buf: UnsafeMutablePointer<pbuf>?, ipaddr: UnsafeMutablePointer<ip_addr_t>?) -> err_t {
    TSIPStack.stack.writeOut(pbuf: buf!)
    return err_t(ERR_OK)
}

/**
 这是接收和输出IP数据包的IP堆栈。
 
  应该在任何输入之前设置“ outputBlock”和“ delegate”。
  然后，当从TUN接口读取新的IP数据包时，调用`receivedPacket（_ :)`。
 
  内部有一个计时器。 当设备进入睡眠状态（这意味着计时器将在一段时间内不触发）时，必须通过调用“ suspendTimer（）”将计时器暂停，并在设备唤醒时由“ resumeTimer（）”重新启动计时器。
 
  -注意：此类不是线程安全的。
 */
public final class TSIPStack {
    /// The singleton stack instance that developer should use. The `init()` method is a private method, which means there will never be more than one IP stack running at the same time.
    ///开发人员应使用的单例堆栈实例。 “ init（）”方法是一种私有方法，这意味着永远不会有多个IP堆栈同时运行。
    public static var stack = TSIPStack()
    
    // The whole stack is running in this dispatch queue.
    public var processQueue = DispatchQueue(label: "tun2socks.IPStackQueue", attributes: [])
    
    var timer: DispatchSourceTimer?
    let listenPCB: UnsafeMutablePointer<tcp_pcb>
    
    ///当IP堆栈决定输出某些IP数据包时，将调用此块。
    ///
    ///-警告：应在任何输入之前设置此项。
    public var outputBlock: (([Data], [NSNumber]) -> ())!
    
    ///委托实例。
    ///
    ///-警告：此变量的设置在GCD队列中不受保护，因此应在任何输入之前设置此参数，此参数之后不得更改。
    public weak var delegate: TSIPStackDelegate?
    
    //因为我们只需要一个模拟接口，所以我们只使用lwip提供的环回接口。
    //无需添加任何接口。
    var interface: UnsafeMutablePointer<netif> {
        return netif_list
    }
    
    private init() {
        lwip_init()
        // add a listening pcb
        var pcb = tcp_new()
        var addr = ip_addr_any
        tcp_bind(pcb, &addr, 0)
        pcb = tcp_listen_with_backlog(pcb, UInt8(TCP_DEFAULT_LISTEN_BACKLOG))
        listenPCB = pcb!
        tcp_accept(pcb, tcpAcceptFn)
        netif_list.pointee.output = outputPCB
    }
    
    private func checkTimeout() {
        sys_check_timeouts()
    }
    
    func dispatch_call(_ block: @escaping () -> ()) {
        processQueue.async(execute: block)
    }
    
    /**
    暂停计时器。 设备进入睡眠状态时应暂停计时器。
     */
    public func suspendTimer() {
        timer = nil
    }
    
    /**
     唤醒设备后恢复计时器。
     
      -警告：除非未恢复堆栈或暂停计时器，否则请勿调用此方法。
     */
    public func resumeTimer() {
        timer = DispatchSource.makeTimerSource(queue: processQueue)
        //注意，默认的tcp_tmr间隔为250 ms。
        //我不知道设置余地的最佳方法。
        timer!.schedule(deadline: DispatchTime.distantFuture , repeating: DispatchTimeInterval.microseconds(250), leeway: DispatchTimeInterval.microseconds(250))
        timer!.setEventHandler {
            [weak self] in
            self?.checkTimeout()
        }
        sys_restart_timeouts()
        timer!.resume()
    }
    
    /**
     输入一个IP包。
     
      -参数包：包含整个IP包的数据。
     */
    public func received(packet: Data) {
        //由于swift的限制，如果我们想实现零拷贝实现，则必须将`pbuf.payload`的定义更改为`const`，这是不可能的。
        //因此，无论如何我们都必须复制数据。
        let buf = pbuf_alloc(PBUF_RAW, UInt16(packet.count), PBUF_RAM)!
        packet.copyBytes(to: buf.pointee.payload.bindMemory(to: UInt8.self, capacity: packet.count), count: packet.count)
        
        // The `netif->input()` should be ip_input(). According to the docs of lwip, we do not pass packets into the `ip_input()` function directly.
        _ = netif_list.pointee.input(buf, interface)
    }
    
    //写入数据
    func writeOut(pbuf: UnsafeMutablePointer<pbuf>) {
        var data = Data(count: Int(pbuf.pointee.tot_len))
        _ = data.withUnsafeMutableBytes { p in
            pbuf_copy_partial(pbuf, p.baseAddress, pbuf.pointee.tot_len, 0)
        }
        // Only support IPv4 as of now.
        outputBlock([data], [NSNumber(value: AF_INET)])
    }
    
    //收到回应
    func didAcceptTCPSocket(_ pcb: UnsafeMutablePointer<tcp_pcb>, error: err_t) -> err_t {
        tcp_accepted_c(listenPCB)
        delegate?.didAcceptTCPSocket(TSTCPSocket(pcb: pcb, queue: processQueue))
        return err_t(ERR_OK)
    }
}
