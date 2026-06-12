//
//  LosslessSwitcherAudioPlugin.cpp
//  LosslessSwitcherAudioPlugin
//
//  Created by GitHub Copilot on behalf of the user.
//
//  Implementation of the Audio Server Plugin driver for LosslessSwitcher.
//  ロスレススイッチャー用 Audio Server Plugin ドライバの実装。

#include "LosslessSwitcherAudioPlugin.h"
#include <stdio.h>
#include <string.h>
#include <ApplicationServices/ApplicationServices.h>
#include <libproc.h>

#pragma mark - Global State

// Global device object / グローバルデバイスオブジェクト
static LosslessSwitcherDevice g_device = {};
static SampleRateChangeCallback g_sampleRateCallback = nullptr;
static void* g_callbackUserData = nullptr;
static dispatch_once_t g_initOnce = 0;

#pragma mark - Helper Functions

// Get process name from PID
// PID からプロセス名を取得
static void GetProcessNameFromPID(pid_t pid, char* outName, size_t nameSize) {
    if (proc_name(pid, outName, (uint32_t)nameSize) <= 0) {
        snprintf(outName, nameSize, "Unknown (PID: %d)", pid);
    }
}

// Get bundle ID from PID
// PID からバンドルIDを取得
static void GetBundleIDFromPID(pid_t pid, char* outBundleID, size_t bundleIDSize) {
    // In a production system, we'd use Launch Services or similar to get the bundle ID
    // 本番環境では Launch Services などを使用してバンドルID を取得します
    
    ProcessSerialNumber psn;
    if (GetProcessForPID(pid, &psn) != noErr) {
        snprintf(outBundleID, bundleIDSize, "unknown.bundle.%d", pid);
        return;
    }
    
    CFDictionaryRef processInfo = ProcessInformationCopyDictionary(&psn, kProcessDictionaryIncludeAllInformationMask);
    if (processInfo) {
        CFStringRef bundleIDRef = (CFStringRef)CFDictionaryGetValue(processInfo, kCFBundleIdentifierKey);
        if (bundleIDRef) {
            CFStringGetCString(bundleIDRef, outBundleID, (CFIndex)bundleIDSize, kCFStringEncodingUTF8);
        }
        CFRelease(processInfo);
    }
}

// Notify Swift side of sample rate change
// サンプルレート変更を Swift 側に通知
static void NotifySampleRateChange(pid_t clientPID,
                                   const char* bundleID,
                                   Float64 newSampleRate,
                                   UInt32 bitDepth) {
    if (g_sampleRateCallback) {
        dispatch_async(dispatch_get_main_queue(), ^{
            g_sampleRateCallback(clientPID, bundleID, newSampleRate, bitDepth);
        });
    }
    
    fprintf(stderr, "[LosslessSwitcherPlugin] Sample Rate Changed: PID=%d, Rate=%.1f Hz, BitDepth=%u bits\n",
            clientPID, newSampleRate, bitDepth);
}

#pragma mark - Plugin Initialization

OSStatus LosslessSwitcherPlugin_Initialize(AudioServerPlugInDriverRef inDriver) {
    fprintf(stderr, "[LosslessSwitcherPlugin] Initialize called\n");
    
    dispatch_once(&g_initOnce, ^{
        g_device.driverRef = inDriver;
        g_device.deviceID = kAudioObjectSystemObject + 1;  // Unique device ID
        g_device.inputStreamID = g_device.deviceID + 1;
        g_device.outputStreamID = g_device.deviceID + 2;
        
        g_device.accessQueue = dispatch_queue_create("com.vincent-neo.losslessswitcher.access", DISPATCH_QUEUE_SERIAL);
        
        // Initialize default format (44.1kHz, 2ch, Float32)
        // デフォルトフォーマットを初期化 (44.1kHz, 2ch, Float32)
        g_device.currentFormat.mSampleRate = 44100.0;
        g_device.currentFormat.mFormatID = kAudioFormatLinearPCM;
        g_device.currentFormat.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        g_device.currentFormat.mBytesPerPacket = 4;
        g_device.currentFormat.mFramesPerPacket = 1;
        g_device.currentFormat.mBytesPerFrame = 4;
        g_device.currentFormat.mChannelsPerFrame = 2;
        g_device.currentFormat.mBitsPerChannel = 32;
        
        fprintf(stderr, "[LosslessSwitcherPlugin] Initialized with device ID: %u\n", g_device.deviceID);
    });
    
    return noErr;
}

OSStatus LosslessSwitcherPlugin_Finalize(AudioServerPlugInDriverRef inDriver) {
    fprintf(stderr, "[LosslessSwitcherPlugin] Finalize called\n");
    
    if (g_device.accessQueue) {
        dispatch_release(g_device.accessQueue);
        g_device.accessQueue = nullptr;
    }
    
    return noErr;
}

#pragma mark - Property Access

OSStatus LosslessSwitcherPlugin_GetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientPID,
    const AudioServerPlugInAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    UInt32* outDataSize,
    void* outData) {
    
    // Handle various CoreAudio properties
    // 様々な CoreAudio プロパティを処理
    
    if (!inAddress || !outDataSize) {
        return kAudioHardwareBadPropertyError;
    }
    
    __block OSStatus result = kAudioHardwareBadPropertyError;
    
    dispatch_sync(g_device.accessQueue, ^{
        switch (inAddress->mSelector) {
            case kAudioDevicePropertyStreamFormat: {
                if (inDataSize >= sizeof(AudioStreamBasicDescription)) {
                    *outDataSize = sizeof(AudioStreamBasicDescription);
                    memcpy(outData, &g_device.currentFormat, sizeof(AudioStreamBasicDescription));
                    result = noErr;
                }
                break;
            }
            
            case kAudioDevicePropertyNominalSampleRate: {
                if (inDataSize >= sizeof(Float64)) {
                    *outDataSize = sizeof(Float64);
                    *(Float64*)outData = g_device.currentFormat.mSampleRate;
                    result = noErr;
                }
                break;
            }
            
            case kAudioDevicePropertyBufferFrameSize: {
                if (inDataSize >= sizeof(UInt32)) {
                    *outDataSize = sizeof(UInt32);
                    *(UInt32*)outData = 512;  // Default buffer size
                    result = noErr;
                }
                break;
            }
            
            default:
                result = kAudioHardwareUnknownPropertyError;
                break;
        }
    });
    
    return result;
}

OSStatus LosslessSwitcherPlugin_SetPropertyData(
    AudioServerPlugInDriverRef inDriver,
    AudioObjectID inObjectID,
    pid_t inClientPID,
    const AudioServerPlugInAddress* inAddress,
    UInt32 inQualifierDataSize,
    const void* inQualifierData,
    UInt32 inDataSize,
    const void* inData) {
    
    if (!inAddress || !inData) {
        return kAudioHardwareBadPropertyError;
    }
    
    __block OSStatus result = kAudioHardwareBadPropertyError;
    
    dispatch_sync(g_device.accessQueue, ^{
        switch (inAddress->mSelector) {
            case kAudioDevicePropertyNominalSampleRate: {
                if (inDataSize >= sizeof(Float64)) {
                    Float64 newSampleRate = *(Float64*)inData;
                    Float64 oldSampleRate = g_device.currentFormat.mSampleRate;
                    
                    // Only process if sample rate actually changed
                    // サンプルレートが実際に変更された場合のみ処理
                    if (abs(newSampleRate - oldSampleRate) > 0.1) {
                        g_device.currentFormat.mSampleRate = newSampleRate;
                        
                        // Extract bit depth from format
                        UInt32 bitDepth = g_device.currentFormat.mBitsPerChannel;
                        
                        // Get process info
                        char bundleID[256] = {0};
                        GetBundleIDFromPID(inClientPID, bundleID, sizeof(bundleID));
                        
                        // Update active source
                        g_device.activeSource.processID = inClientPID;
                        strncpy(g_device.activeSource.bundleID, bundleID, sizeof(g_device.activeSource.bundleID) - 1);
                        g_device.activeSource.sampleRate = (uint32_t)newSampleRate;
                        g_device.activeSource.bitDepth = bitDepth;
                        memcpy(&g_device.activeSource.format, &g_device.currentFormat, sizeof(AudioStreamBasicDescription));
                        
                        // Notify Swift side
                        NotifySampleRateChange(inClientPID, bundleID, newSampleRate, bitDepth);
                        
                        result = noErr;
                    }
                }
                break;
            }
            
            case kAudioDevicePropertyStreamFormat: {
                if (inDataSize >= sizeof(AudioStreamBasicDescription)) {
                    AudioStreamBasicDescription* newFormat = (AudioStreamBasicDescription*)inData;
                    
                    Float64 newSampleRate = newFormat->mSampleRate;
                    UInt32 bitDepth = newFormat->mBitsPerChannel;
                    
                    memcpy(&g_device.currentFormat, newFormat, sizeof(AudioStreamBasicDescription));
                    
                    char bundleID[256] = {0};
                    GetBundleIDFromPID(inClientPID, bundleID, sizeof(bundleID));
                    
                    NotifySampleRateChange(inClientPID, bundleID, newSampleRate, bitDepth);
                    
                    result = noErr;
                }
                break;
            }
            
            default:
                result = kAudioHardwareUnknownPropertyError;
                break;
        }
    });
    
    return result;
}

#pragma mark - IO Operations

OSStatus LosslessSwitcherPlugin_ReadRawAudioStream(
    AudioServerPlugInDriverRef inDriver,
    const AudioServerPlugInAddress* inAddress,
    const AudioStreamBasicDescription* inFormat,
    const AudioBufferList* outBufferList,
    AudioServerPlugInIOCycleContext* ioContext) {
    
    // In a production implementation, this would perform actual audio I/O
    // and call the ring buffer for buffering/delay.
    //
    // 本番環境では、実際のオーディオ I/O を実行し、
    // バッファリング/遅延のためリングバッファを呼び出します。
    
    if (!outBufferList || outBufferList->mNumberBuffers == 0) {
        return noErr;
    }
    
    // Initialize buffers with silence for now
    // 現在のところ、バッファをサイレンスで初期化
    for (UInt32 i = 0; i < outBufferList->mNumberBuffers; ++i) {
        if (outBufferList->mBuffers[i].mData) {
            memset(outBufferList->mBuffers[i].mData, 0, outBufferList->mBuffers[i].mDataByteSize);
        }
    }
    
    return noErr;
}

#pragma mark - Callback Registration

void LosslessSwitcherPlugin_RegisterSampleRateCallback(
    SampleRateChangeCallback callback,
    void* userData) {
    
    dispatch_sync(g_device.accessQueue, ^{
        g_sampleRateCallback = callback;
        g_callbackUserData = userData;
        fprintf(stderr, "[LosslessSwitcherPlugin] Callback registered\n");
    });
}

#pragma mark - Audio Server Plugin Main Entry

// This is the main entry point for CoreAudio to load the plugin
// CoreAudio がプラグインをロードするためのメインエントリーポイント
extern "C" {

OSStatus AudioServerPlugInDriverEntry(
    AudioServerPlugInDriverRef inDriver,
    const AudioServerPlugInAddress* inAddress,
    UInt32 inSelector,
    UInt32 inDataSize,
    const void* inData,
    UInt32* outDataSize,
    void* outData) {
    
    switch (inSelector) {
        case kAudioServerPlugInInitializeSelect:
            return LosslessSwitcherPlugin_Initialize(inDriver);
            
        case kAudioServerPlugInFinalizeSelect:
            return LosslessSwitcherPlugin_Finalize(inDriver);
            
        case kAudioServerPlugInGetPropertyDataSelect:
            return LosslessSwitcherPlugin_GetPropertyData(
                inDriver,
                inAddress->mObjectID,
                inAddress->mClientPID,
                inAddress,
                inDataSize,
                inData,
                *((UInt32*)outDataSize),
                (UInt32*)outDataSize,
                outData);
            
        case kAudioServerPlugInSetPropertyDataSelect:
            return LosslessSwitcherPlugin_SetPropertyData(
                inDriver,
                inAddress->mObjectID,
                inAddress->mClientPID,
                inAddress,
                inDataSize,
                inData,
                *(UInt32*)outDataSize,
                outData);
            
        case kAudioServerPlugInIOOperationSelect:
            // For now, we don't implement direct I/O operations
            // 現在のところ、直接的な I/O 操作は実装していません
            return kAudioHardwareUnsupportedOperationError;
            
        default:
            return kAudioHardwareUnsupportedOperationError;
    }
}

}  // extern "C"
