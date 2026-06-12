//
//  Defaults.swift
//  Quality
//
//  Created by Vincent Neo on 23/4/22.
//

import Foundation

class Defaults: ObservableObject {
    static let shared = Defaults()
    private let kUserPreferIconStatusBarItem = "com.vincent-neo.LosslessSwitcher-Key-UserPreferIconStatusBarItem"
    private let kSelectedDeviceUID = "com.vincent-neo.LosslessSwitcher-Key-SelectedDeviceUID"
    private let kUserPreferBitDepthDetection = "com.vincent-neo.LosslessSwitcher-Key-BitDepthDetection"
    private let kShellScriptPath = "KeyShellScriptPath"
    private let kUserPreferSampleRateMultiples = "PreferSampleRateMultiples"
    private let kUserPreferLowLatencyMode = "PreferLowLatencyMode"
    private let kUserPreferMuteNotifications = "PreferMuteNotifications"
    private let kUserPreferAutoUpdateCheck = "PreferAutoUpdateCheck"
    
    private init() {
        UserDefaults.standard.register(defaults: [
            kUserPreferIconStatusBarItem : true,
            kUserPreferBitDepthDetection : false,
            kUserPreferSampleRateMultiples : false,
            kUserPreferLowLatencyMode : false,
            kUserPreferMuteNotifications : false,
            kUserPreferAutoUpdateCheck : true
        ])
        
        self.shellScriptPath = UserDefaults.standard.string(forKey: kShellScriptPath)
        self.userPreferIconStatusBarItem = UserDefaults.standard.bool(forKey: kUserPreferIconStatusBarItem)
        self.userPreferBitDepthDetection = UserDefaults.standard.bool(forKey: kUserPreferBitDepthDetection)
        self.userPreferSampleRateMultiples = UserDefaults.standard.bool(forKey: kUserPreferSampleRateMultiples)
        self.userPreferLowLatencyMode = UserDefaults.standard.bool(forKey: kUserPreferLowLatencyMode)
        self.userPreferMuteNotifications = UserDefaults.standard.bool(forKey: kUserPreferMuteNotifications)
        self.userPreferAutoUpdateCheck = UserDefaults.standard.bool(forKey: kUserPreferAutoUpdateCheck)
    }
    
    @Published var userPreferIconStatusBarItem: Bool {
        willSet {
            UserDefaults.standard.set(newValue, forKey: kUserPreferIconStatusBarItem)
        }
    }
    
    var selectedDeviceUID: String? {
        get {
            return UserDefaults.standard.string(forKey: kSelectedDeviceUID)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kSelectedDeviceUID)
        }
    }
    
    @Published var shellScriptPath: String? {
        willSet {
            UserDefaults.standard.setValue(newValue, forKey: kShellScriptPath)
        }
    }
    
    @Published var userPreferSampleRateMultiples: Bool {
        willSet {
            UserDefaults.standard.set(newValue, forKey: kUserPreferSampleRateMultiples)
        }
    }
    
    @Published var userPreferLowLatencyMode: Bool {
        willSet {
            UserDefaults.standard.set(newValue, forKey: kUserPreferLowLatencyMode)
        }
    }
    
    @Published var userPreferMuteNotifications: Bool {
        willSet {
            UserDefaults.standard.set(newValue, forKey: kUserPreferMuteNotifications)
        }
    }
    
    @Published var userPreferAutoUpdateCheck: Bool {
        willSet {
            UserDefaults.standard.set(newValue, forKey: kUserPreferAutoUpdateCheck)
        }
    }
    
    @Published var userPreferBitDepthDetection: Bool
    
    
    @MainActor func setPreferBitDepthDetection(newValue: Bool) {
        UserDefaults.standard.set(newValue, forKey: kUserPreferBitDepthDetection)
        self.userPreferBitDepthDetection = newValue
    }
    
    @MainActor func setShellScriptPath(newValue: String?) {
        self.shellScriptPath = newValue
    }
    
    @MainActor func setPreferSampleRateMultiple(newValue: Bool) {
        self.userPreferSampleRateMultiples = newValue
    }

    var statusBarItemTitle: String {
        let title = self.userPreferIconStatusBarItem ? "Show Sample Rate" : "Show Icon"
        return title
    }
}
