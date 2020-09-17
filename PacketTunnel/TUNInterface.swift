import Foundation
import NetworkExtension


/// TUN interface provide a scheme to register a set of IP Stacks (implementing `IPStackProtocol`) to process IP packets from a virtual TUN interface.
//TUN接口提供了一种方案，用于注册一组IP堆栈（实现“ IPStackProtocol”）以处理来自虚拟TUN接口的IP数据包。

open class TUNInterface {
    fileprivate weak var packetFlow: NEPacketTunnelFlow?
    fileprivate var stacks: [IPStackProtocol] = []
    
    /**
  用数据包流初始化TUN接口。
     -参数packetFlow：要使用的数据包流。
     */
    public init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }
    
    /**
     开始处理数据包，注册所有IP堆栈后应调用此方法。
     停止的接口永远不会再次启动。而是创建一个新界面。
     */
    open func start() {
        QueueFactory.executeOnQueueSynchronizedly {
            for stack in self.stacks {
                stack.start()
            }
            self.readPackets()
        }
    }
    
    /**

     停止处理数据包，应在释放接口之前调用它。

     */
    open func stop() {
        QueueFactory.executeOnQueueSynchronizedly {
            self.packetFlow = nil
            for stack in self.stacks {
                stack.stop()
            }
            self.stacks = []
        }
    }
    
    /**
     注册一个新的IP堆栈。
     从TUN接口读取数据包时（数据包流），数据包将根据注册顺序传递到每个IP堆栈中，直到其中一个将其接收为止。
     -参数堆栈：要添加到堆栈列表的IP堆栈。
     */
    open func register(stack: IPStackProtocol) {
        QueueFactory.executeOnQueueSynchronizedly {
            stack.outputFunc = self.generateOutputBlock()
            self.stacks.append(stack)
        }
    }
    
    //读取数据
    fileprivate func readPackets() {
        //packets 和 version 各是一个对象数组，相对应的数组索引中的nsdata和nsnumber 代表一个数据包，
        packetFlow?.readPackets { packets, versions in
            QueueFactory.getQueue().async {
                for (i, packet) in packets.enumerated() {
                    for stack in self.stacks {
                        if stack.input(packet: packet, version: versions[i]) {
                            break
                        }
                    }
                }
            }
            self.readPackets()
        }
    }
    
    // 写入app 的block 回调
    fileprivate func generateOutputBlock() -> ([Data], [NSNumber]) -> Void {
        return { [weak self] packets, versions in
            NSLog("wuplyer ---- 将数据写回app")
            self?.packetFlow?.writePackets(packets, withProtocols: versions)
        }
    }
}
