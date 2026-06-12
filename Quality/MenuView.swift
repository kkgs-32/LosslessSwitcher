//
//  MenuView.swift
//  LosslessSwitcher
//
//  Created by Vincent Neo on 23/6/25.
//

import SwiftUI

struct MenuView: View {
    
    @EnvironmentObject private var outputDevices: OutputDevices
    @EnvironmentObject private var audioRoutingController: AudioRoutingController
    @EnvironmentObject private var defaults: Defaults
    
    var body: some View {
        VStack {
            ContentView()
            
            Divider()
            
            Button {
                defaults.userPreferIconStatusBarItem.toggle()
            } label: {
                Text(defaults.statusBarItemTitle)
            }
            
            Button {
                defaults.userPreferBitDepthDetection.toggle()
            } label: {
                HStack {
                    Text("Bit Depth Switching")
                    if defaults.userPreferBitDepthDetection {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button {
                defaults.userPreferSampleRateMultiples.toggle()
            } label: {
                HStack {
                    Text("Prefer Closest Sample Rate Multiple")
                    if defaults.userPreferSampleRateMultiples {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                defaults.userPreferLowLatencyMode.toggle()
            } label: {
                HStack {
                    Text("Low Latency Mode")
                    if defaults.userPreferLowLatencyMode {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button {
                defaults.userPreferMuteNotifications.toggle()
            } label: {
                HStack {
                    Text("Mute Notification Sounds")
                    if defaults.userPreferMuteNotifications {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            Button {
                audioRoutingController.toggleManualRoutingPause()
            } label: {
                HStack {
                    Text(audioRoutingController.isManualRoutingPaused ? "Resume Auto Routing" : "Pause Auto Routing")
                    if audioRoutingController.isManualRoutingPaused {
                        Image(systemName: "pause.circle")
                    }
                }
            }
            
            Text("Virtual Device: Proxy / BlackHole Layer")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(audioRoutingController.virtualDeviceStatus)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Divider()

            Group {
                Text("Active Sources")
                    .font(.headline)
                if audioRoutingController.rankedSources.isEmpty {
                    Text("No active sources detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(audioRoutingController.rankedSources) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.displayName)
                                    .font(.subheadline)
                                Text("\(source.readableSampleRate) · \(source.readableBitDepth)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(spacing: 4) {
                                Button(action: {
                                    audioRoutingController.moveSource(source, up: true)
                                }) {
                                    Image(systemName: "arrow.up")
                                }
                                Button(action: {
                                    audioRoutingController.moveSource(source, up: false)
                                }) {
                                    Image(systemName: "arrow.down")
                                }
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
            }

            Divider()

            Menu {
                Button {
                    outputDevices.selectedOutputDevice = nil
                    defaults.selectedDeviceUID = nil
                } label: {
                    if outputDevices.selectedOutputDevice == nil {
                        Image(systemName: "checkmark")
                    }
                    Text("Default Device")
                }
                    if outputDevices.selectedOutputDevice == nil {
                        Image(systemName: "checkmark")
                    }
                    Text("Default Device")
                }

                ForEach(outputDevices.outputDevices, id: \.uid) { device in
                    Button {
                        outputDevices.selectedOutputDevice = device
                        defaults.selectedDeviceUID = device.uid
                    } label: {
                        Text(device.name)
                        if outputDevices.selectedOutputDevice?.uid == device.uid {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Text("Selected Device")
            }
            
            Menu {
                Text("Version - \(currentVersion)")
                Text("Build - \(currentBuild)")
            } label: {
                Text("About")
            }
            
            Menu {
                Button("Select Script...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.message = "Select a script that should be invoked when sample rate changes."
                    
                    panel.begin { response in
                        let path = panel.url?.path
                        DispatchQueue.main.async { [weak defaults] in
                            defaults?.shellScriptPath = path
                        }
                    }
                }
                
                Button("Clear Selection") {
                    defaults.shellScriptPath = nil
                }
                
                Text(defaults.shellScriptPath ?? "No selection")
                
            } label: {
                Text("Scripting")
            }
            
            Button {
                NSApp.terminate(self)
            } label: {
                Text("Quit LosslessSwitcher")
            }
        }
    }
}
