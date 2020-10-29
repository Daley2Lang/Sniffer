//
//  ViewController.swift
//  Sniffer
//
//  Created by ZapCannon87 on 22/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import UIKit
import NetworkExtension
import CocoaAsyncSocket

class ViewController: UIViewController {
    
    let reciversockt = GCDAsyncUdpSocket()
    
    @IBOutlet weak var infoView: UITextView!
    @IBOutlet weak var showLabel: UILabel!
    @IBOutlet weak var cilickBtn: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var status  : VPNStatus!{
        didSet(o){
            updateConnectButton()
        }
    }
    
    @IBAction func udpClick(_ sender: Any) {
        let info  = "udp test string"
        let data = info.data(using:.utf8)
        reciversockt.send(data!, toHost: "118.24.182.119", port:9502, withTimeout: -1, tag: 0)
    }
    @IBAction func clearinfo(_ sender: Any) {
        self.infoView.text = ""
        self.showLabel.text = ""
    }
    
    lazy var oneSwitch: UISwitch = {
        return (self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! SwitchCell).oneSwitch
    }()
    
    @IBAction func refreshNet(_ sender: Any) {
        
        Tool.getIPAddress(0)
        
    }
    @IBAction func click(_ sender: Any) {
        print("connect tap")
        if(VpnManager.shared.vpnStatus == .off){
            VpnManager.shared.connect()
        }else{
            VpnManager.shared.disconnect()
        }
    }
    //   cilickBtn.setTitle("Connect", for: UIControl.State())
    
    @IBAction func sendMsg(_ sender: UIButton) {
        
        let session  = URLSession.shared
//        let url = URL.init(string: "http://182.92.2.5:8805/write?msg=str_from_http")
        
        let url = URL.init(string: "http://182.92.2.5:8805//read?num=25500")
        
        
        let dataTask = session.dataTask(with: url!) { (data, res, error) in
            guard error == nil else{
                return
            }
            
            
            let dataStr = String.init(data: data!, encoding: String.Encoding.utf8)
            
            if Thread.isMainThread {
                self.showLabel.text = "请求成功"
                self.infoView.text = dataStr
            } else {
                DispatchQueue.main.async {
                     self.showLabel.text = "请求成功"
                    self.infoView.text = dataStr
                }
            }
            
            print("收到的数据：\(dataStr!)")
            
        }
        
        dataTask.resume()
    }
    
    
    @IBAction func requestHost(_ sender: Any) {
        
        let session  = URLSession.shared
               let url = URL.init(string: "http://api.codertopic.com/itapi/questionsapi/questions.php?typeID=1")
//        49    1.028199    10.0.0.93    123.56.237.10    HTTP    286    GET /itapi/questionsapi/questions.php?typeID=10 HTTP/1.1
//        88    4.064181    10.0.0.93    123.56.237.10    HTTP    341    GET http://api.codertopic.com/itapi/questionsapi/questions.php?typeID=10 HTTP/1.1
        
        let str = getIPAddress(domainName: "api.codertopic.com")
        
        NSLog("当前域名的 IP 地址:%@",str)
        
        
//                let url = URL.init(string: "http://imdns.hpplay.cn/Author/GetImServer?uid=7092130147765849530&appid=13578&token=fd8f68259fada2b11600422603")
        
//        http://p9-xg.byteimg.com/img/tos-cn-i-0004/e3054ac894ce4211ae090c21d002a1ef~c5_q75_864x486.webp
        
               let dataTask = session.dataTask(with: url!) { (data, res, error) in
                   guard error == nil else{
                    
                    NSLog("请求错误信息:\(String(describing: error))")
                    
                       return
                   }
                
                    
                
                   let dataStr = String.init(data: data!, encoding: String.Encoding.utf8)
                   let dic  =  self.stringValueDic(dataStr!)
                
                   if Thread.isMainThread {
                       self.infoView.text = dataStr
                   } else {
                       DispatchQueue.main.async {
                           self.infoView.text = dataStr
                       }
                   }
                   
                   print("收到的数据：\(dic!)")
                   
               }
               
               dataTask.resume()
    }
    
    // MARK: 字典转字符串
    func dicValueString(_ dic:[String : Any]) -> String?{
        let data = try? JSONSerialization.data(withJSONObject: dic, options: [])
        let str = String(data: data!, encoding: String.Encoding.utf8)
        return str
    }
    
    // MARK: 字符串转字典
    func stringValueDic(_ str: String) -> [String : Any]?{
        let data = str.data(using: String.Encoding.utf8)
        if let dict = try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] {
            return dict
        }
        return nil
    }
    
    func updateConnectButton(){
        switch status {
        case .connecting:
            cilickBtn.setTitle("connecting", for: UIControl.State())
        case .disconnecting:
            cilickBtn.setTitle("disconnect", for: UIControl.State())
        case .on:
            cilickBtn.setTitle("Disconnect", for: UIControl.State())
        case .off:
            cilickBtn.setTitle("Connect", for: UIControl.State())
            
        case .none:
            cilickBtn.setTitle("Connect", for: UIControl.State())
        }
        cilickBtn.isEnabled = [VPNStatus.on,VPNStatus.off].contains(VpnManager.shared.vpnStatus)
        
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let numbers = [1, 2, 3, 4]
        let numberSum = numbers.reduce(0, { x, y in
            x + y
        })
        
        NSLog("累加的值 \(numberSum)")
        
        
        ponteeTest()
        
        //        NotificationCenter.default.addObserver(
        //            self,
        //            selector: #selector(self.vpnStatusDidChange),
        //            name: .NEVPNStatusDidChange,
        //            object: nil
        //        )
        //        NotificationCenter.default.addObserver(
        //            self,
        //            selector: #selector(self.vpnConfigurationChange),
        //            name: .NEVPNConfigurationChange,
        //            object: nil
        //        )
        //
        //        self.viewActive(enable: false)
        //        TunnelManager.shared.loadAllFromPreferences() {
        //            self.viewActive(enable: true)
        //            NotificationCenter.default.post(
        //                name: .NEVPNStatusDidChange,
        //                object: nil
        //            )
        //        }
    }
    
    required init?(coder: NSCoder) {
        self.status = .off
        
        super.init(coder:coder)
        reciversockt.synchronouslySetDelegate(self, delegateQueue:  DispatchQueue(label: "HTTPProxyServer.delegateQueue"))
        
        do {
            try reciversockt.bind(toPort: 9528)
        } catch {
            assertionFailure("\(error)")
        }
        
        do {
            try reciversockt.enableBroadcast(true)
        } catch {
            assertionFailure("\(error)")
        }
        
        do {
            try reciversockt.beginReceiving()
        } catch {
            assertionFailure("\(error)")
        }
        NotificationCenter.default.addObserver(self, selector: #selector(onVPNStatusChanged), name: Notification.Name(rawValue: kProxyServiceVPNStatusNotification), object: nil)
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    
    @objc func onVPNStatusChanged(){
        self.status = VpnManager.shared.vpnStatus
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.status = VpnManager.shared.vpnStatus
    }
    
    
    func viewActive(enable: Bool) {
        self.view.isUserInteractionEnabled = enable
        if enable {
            self.activityIndicator.stopAnimating()
        } else {
            self.activityIndicator.startAnimating()
        }
    }
    
    @objc func vpnStatusDidChange() {
        guard let tpm = TunnelManager.tpm else {
            return
        }
        let status: NEVPNStatus = tpm.session.status
        self.oneSwitch.setOn(
            (status == .connected || status == .connecting),
            animated: false
        )
    }
    
    @objc func vpnConfigurationChange() {
        guard let tpm = TunnelManager.tpm else {
            return
        }
        self.viewActive(enable: false)
        tpm.loadFromPreferences() { loadErr in
            self.viewActive(enable: true)
            if let err: Error = loadErr {
                print(err)
            }
        }
    }
    
    
    func ponteeTest()  -> Void {
        struct Rich {
            var money: Int
            var isRich: Bool
        }
        var rich = Rich(money: 99999999, isRich: true)
//        通过withUnsafeBytes获取可变原生缓冲类型指针，可获取到rich中每个字节的值
        withUnsafeBytes(of: &rich) { bytes in
            
            print("输出bytes: \(bytes)")
            
            for byte in bytes {
                print("使劲输出 \(byte)")
            }
        }
        print("---------------")

//        withUnsafeMutablePointer 获取可变指针
//        withUnsafeMutableBufferPointer 获取可变缓冲类型指针
        let richP = withUnsafeMutablePointer(to: &rich) { UnsafeMutableRawPointer($0) }
        let moneyP = richP.assumingMemoryBound(to: Int.self)
        moneyP.pointee = 0
        print("输出money:\(rich.money)")
        let isRichP = richP.advanced(by: MemoryLayout<Int>.stride).assumingMemoryBound(to: Bool.self)
        isRichP.pointee = false
        print(rich.isRich)
         print("输出isRich:\(rich.isRich)")
    }
    
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return tableView.dequeueReusableCell(withIdentifier: "SwitchCell") as! SwitchCell
        case (1, 0):
            let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "1")!
            cell.textLabel?.text = "Sessions"
            return cell
        default:
            fatalError()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            let vc: SessionsViewController = self.storyboard?.instantiateViewController(withIdentifier: "SessionsViewController") as! SessionsViewController
            self.navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
    
}

extension ViewController:GCDAsyncUdpSocketDelegate{
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        NSLog("udp 数据发送成功")
        DispatchQueue.main.async {
            self.showLabel.text = "udp 数据发送成功"
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        NSLog("udp 数据发送失败")
        DispatchQueue.main.async {
            self.showLabel.text = "udp 数据发送失败"
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        
        let str = String.init(data: data, encoding: .utf8)
        DispatchQueue.main.async {
            self.infoView.text = String.init(format: "来自服务端的回应:%@", str!)
        }
        
    }
    
    // 域名解析
     func getIPAddress(domainName: String) -> String {
     var result = ""
         let host = CFHostCreateWithName(nil,domainName as CFString).takeRetainedValue()
         CFHostStartInfoResolution(host, .addresses, nil)
         var success: DarwinBoolean = false
         if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
             let theAddress = addresses.firstObject as? NSData {
             var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
             if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                            &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                 let numAddress = String(cString: hostname)
                 result = numAddress
                 print(numAddress)
             }
         }
         return result
     }

    
}



// MARK: - View

class SwitchCell: UITableViewCell {
    
    @IBOutlet weak var oneSwitch: UISwitch!
    
}


 
