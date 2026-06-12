//
//  VirtualAudioProxy.swift
//  LosslessSwitcher
//
//  Created by GitHub Copilot on behalf of the user.
//

import Foundation
import CoreAudioTypes
import CoreAudio
import AudioToolbox

/// A mock proxy layer that represents the virtual audio device behavior.
/// This is not a real HAL plug-in, but it simulates the ring buffer / sample rate transition logic.
class VirtualAudioProxy {
    private let outputDevices: OutputDevices
    private let ringBuffer: AudioRingBuffer
    private var isActive = false

    init(outputDevices: OutputDevices) {
        self.outputDevices = outputDevices
        self.ringBuffer = AudioRingBuffer(sampleRate: 44100, channels: 2, delaySeconds: 0.2)
    }

    func startProxy() {
        // In a real implementation, this would initialize the virtual device and register it with CoreAudio.
        // 実際の実装では、ここで仮想デバイスを初期化し、CoreAudio に登録します。
        isActive = true
        print("[VirtualAudioProxy] started proxy layer")
    }

    func prepareBufferedTransition(sampleRate: Double, bitDepth: Int) {
        guard isActive else { return }
        print("[VirtualAudioProxy] preparing buffered transition to \(sampleRate) Hz / \(bitDepth) bit")
        ringBuffer.reset(sampleRate: sampleRate, channels: 2)
        ringBuffer.setDelaySeconds(0.2)
    }

    func writeSamples(_ samples: [Float32]) {
        ringBuffer.write(samples: samples)
    }

    func readSamples(count: Int) -> [Float32] {
        return ringBuffer.read(count: count)
    }
}
