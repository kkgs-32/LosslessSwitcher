//
//  AudioRoutingController.swift
//  LosslessSwitcher
//
//  Created by GitHub Copilot on behalf of the user.
//

import Foundation
import AppKit
import CoreAudioTypes
import SimplyCoreAudio

struct AudioSource: Identifiable, Equatable {
    let id = UUID()
    let pid: Int
    let bundleID: String?
    let appName: String
    var sampleRate: Double
    var bitDepth: Int
    var sourceURL: String?
    let isNotificationSource: Bool
    var priority: Int

    var displayName: String {
        if let url = sourceURL, !url.isEmpty {
            return "\(appName) (\(url))"
        }
        return appName
    }

    var readableSampleRate: String {
        return String(format: "%.1f kHz", sampleRate / 1000)
    }

    var readableBitDepth: String {
        return "\(bitDepth) bit"
    }
}

@MainActor
class AudioRoutingController: ObservableObject {
    @Published var prioritySources: [AudioSource] = []
    @Published var virtualDeviceStatus: String = "Proxy idle"
    @Published var activeSampleRate: Double = 44100
    @Published var activeBitDepth: Int = 16
    @Published var isManualRoutingPaused: Bool = false

    private let outputDevices: OutputDevices
    private let defaults = Defaults.shared
    private let virtualProxy: VirtualAudioProxy

    init(outputDevices: OutputDevices) {
        self.outputDevices = outputDevices
        self.virtualProxy = VirtualAudioProxy(outputDevices: outputDevices)
        self.virtualProxy.startProxy()
    }

    var rankedSources: [AudioSource] {
        prioritySources.sorted { $0.priority < $1.priority }
    }

    func addOrUpdateSource(pid: Int,
                           bundleID: String?,
                           appName: String,
                           sampleRate: Double,
                           bitDepth: Int,
                           sourceURL: String? = nil,
                           isNotificationSource: Bool = false) {
        guard !defaults.userPreferMuteNotifications || !isNotificationSource else {
            // If mute notifications is enabled, ignore notification sources.
            // 通知音のミュートが有効な場合、通知音ソースは無視する。
            return
        }

        if let index = prioritySources.firstIndex(where: { $0.pid == pid && $0.bundleID == bundleID }) {
            prioritySources[index].sampleRate = sampleRate
            prioritySources[index].bitDepth = bitDepth
            prioritySources[index].sourceURL = sourceURL
            virtualDeviceStatus = "Updated \(prioritySources[index].displayName)"
        } else {
            let priority = (prioritySources.map { $0.priority }.max() ?? 0) + 1
            let source = AudioSource(pid: pid,
                                     bundleID: bundleID,
                                     appName: appName,
                                     sampleRate: sampleRate,
                                     bitDepth: bitDepth,
                                     sourceURL: sourceURL,
                                     isNotificationSource: isNotificationSource,
                                     priority: priority)
            prioritySources.append(source)
            virtualDeviceStatus = "Added \(source.displayName)"
        }

        self.routeAudioIfNeeded()
    }

    func removeSource(pid: Int, bundleID: String?) {
        prioritySources.removeAll { $0.pid == pid && $0.bundleID == bundleID }
        virtualDeviceStatus = "Removed source for pid \(pid)"
        self.routeAudioIfNeeded()
    }

    func routeAudioIfNeeded() {
        guard !isManualRoutingPaused, let source = rankedSources.first else {
            virtualDeviceStatus = "No active sources"
            return
        }

        activeSampleRate = source.sampleRate
        activeBitDepth = source.bitDepth
        virtualDeviceStatus = "Routing \(source.displayName) at \(source.readableSampleRate) / \(source.readableBitDepth)"

        if !defaults.userPreferLowLatencyMode {
            virtualProxy.prepareBufferedTransition(sampleRate: source.sampleRate, bitDepth: source.bitDepth)
        } else {
            virtualDeviceStatus += " (low latency bypass)"
        }

        if let device = outputDevices.selectedOutputDevice ?? outputDevices.defaultOutputDevice,
           let format = findBestFormat(for: device, sampleRate: source.sampleRate, bitDepth: source.bitDepth) {
            outputDevices.setFormats(device: device, format: format)
            outputDevices.updateSampleRate(source.sampleRate, bitDepth: source.bitDepth)
        }
    }

    func moveSource(_ source: AudioSource, up: Bool) {
        guard let index = rankedSources.firstIndex(of: source) else { return }
        let targetIndex = up ? max(index - 1, 0) : min(index + 1, rankedSources.count - 1)
        if index == targetIndex { return }
        var sources = rankedSources
        sources.swapAt(index, targetIndex)
        for idx in sources.indices {
            sources[idx].priority = idx
        }
        prioritySources = sources
        routeAudioIfNeeded()
    }

    func toggleManualRoutingPause() {
        isManualRoutingPaused.toggle()
        virtualDeviceStatus = isManualRoutingPaused ? "Manual routing paused" : "Auto routing enabled"
        if !isManualRoutingPaused {
            routeAudioIfNeeded()
        }
    }

    func openAudioMIDISetup() {
        // macOS の「オーディオMIDI設定」を開く / Open the Audio MIDI Setup app on macOS.
        let appURL = URL(fileURLWithPath: "/Applications/Utilities/Audio MIDI Setup.app")
        NSWorkspace.shared.open(appURL)
    }

    func checkForUpdates() {
        // TODO: GitHub Releases などの自動更新チェック実装
        virtualDeviceStatus = "Checking for updates..."
    }

    private func findBestFormat(for device: AudioDevice,
                                sampleRate: Double,
                                bitDepth: Int) -> AudioStreamBasicDescription? {
        let streams = device.streams(scope: .output)
        let availableFormats = streams?.first?.availablePhysicalFormats?.compactMap { $0.mFormat }
        let candidate = availableFormats?.min(by: { lhs, rhs in
            let lhsDelta = abs(lhs.mSampleRate - sampleRate) + abs(Double(lhs.mBitsPerChannel - Int32(bitDepth))) * 10
            let rhsDelta = abs(rhs.mSampleRate - sampleRate) + abs(Double(rhs.mBitsPerChannel - Int32(bitDepth))) * 10
            return lhsDelta < rhsDelta
        })
        return candidate
    }
}
