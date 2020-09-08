//
//  TunnelManager.swift
//  Sniffer
//
//  Created by ZapCannon87 on 31/08/2017.
//  Copyright © 2017 zapcannon87. All rights reserved.
//

import Foundation
import NetworkExtension

class TunnelManager {
    
    static let shared: TunnelManager = TunnelManager()
    private var tunnelProviderManager: NETunnelProviderManager?
    static var tpm: NETunnelProviderManager? {
        return self.shared.tunnelProviderManager
    }
    
    private init() {}
    
    func loadAllFromPreferences(completionHandler: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { mgs, loadAllErr in //获取所有的provider
            if let err: Error = loadAllErr {
                assertionFailure("\(err)")
            }
            /* check if created */
            if let tpm: NETunnelProviderManager = mgs?.first { //将第一个provider取出，即当前的vpn provider
                
                TunnelManager.enable(manager: tpm) {
                    self.tunnelProviderManager = tpm
                    completionHandler()
                }
                
            } else {
                /* new tunnel */
                let tpp = NETunnelProviderProtocol()
                tpp.disconnectOnSleep = false
                tpp.providerBundleIdentifier = "com.microwu.qos.extention"
                tpp.serverAddress = "Sniffer"
                let newTpm = NETunnelProviderManager()
                newTpm.protocolConfiguration = tpp
                
                TunnelManager.enable(manager: newTpm) {
                    self.tunnelProviderManager = newTpm
                    completionHandler()
                }
            }
        }
    }
    
    static func enable(manager: NETunnelProviderManager, completionHandler: @escaping () -> Void) {
        manager.isEnabled = true
      
        manager.saveToPreferences() { saveErr in
            if let err: Error = saveErr {
                assertionFailure("\(err)")
            }
            manager.loadFromPreferences() { loadErr in
                if let err: Error = loadErr {
                    assertionFailure("\(err)")
                }
                completionHandler()
            }
        }
    }
    
}
