//
//  AudioRingBuffer.swift
//  LosslessSwitcher
//
//  Created by GitHub Copilot on behalf of the user.
//

import Foundation

/// Simple ring buffer that stores Float32 samples for a given delay.
/// This buffer provides native behavior similar to a virtual audio proxy buffer.
class AudioRingBuffer {
    private var buffer: [Float32]
    private var capacity: Int
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var delaySeconds: Double
    private var sampleRate: Double = 44100
    private var channels: Int = 2

    init(sampleRate: Double, channels: Int, delaySeconds: Double = 0.2) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.delaySeconds = delaySeconds
        self.capacity = Int(sampleRate * Double(channels) * delaySeconds)
        self.buffer = Array(repeating: 0.0, count: self.capacity)
    }

    func reset(sampleRate: Double, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.capacity = Int(sampleRate * Double(channels) * self.delaySeconds)
        self.buffer = Array(repeating: 0.0, count: self.capacity)
        self.writeIndex = 0
        self.readIndex = 0
    }

    func setDelaySeconds(_ seconds: Double) {
        self.delaySeconds = seconds
        let newCapacity = Int(self.sampleRate * Double(self.channels) * seconds)
        if newCapacity != self.capacity {
            self.capacity = max(newCapacity, 1)
            self.buffer = Array(repeating: 0.0, count: self.capacity)
            self.writeIndex = 0
            self.readIndex = 0
        }
    }

    func write(samples: [Float32]) {
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    func read(count: Int) -> [Float32] {
        var output = Array(repeating: Float32(0.0), count: count)
        for i in 0..<count {
            output[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        return output
    }
}
