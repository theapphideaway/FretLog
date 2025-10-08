//
//  AudioRecordingManager.swift
//  Fret Log
//
//  Created by ian schoenrock on 10/7/25.
//

import Foundation
import AVFoundation

class AudioRecordingManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordedAudioData: Data?
    @Published var showingPermissionAlert = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord to allow both recording and playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            print("✓ Audio session configured for recording")
        } catch {
            print("❌ Failed to set up audio session: \(error)")
        }
    }
    
    private func activateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: [])
            print("✓ Audio session activated for recording")
        } catch {
            print("❌ Failed to activate audio session: \(error)")
        }
    }
    
    func startRecording() {
        print("🎙️ Starting recording...")
        
        // Request permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    print("✓ Microphone permission granted")
                    self?.beginRecording()
                } else {
                    print("❌ Microphone permission denied")
                    self?.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func beginRecording() {
        // Clear previous recording
        recordedAudioData = nil
        
        // Reactivate audio session to ensure it's ready
        activateAudioSession()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("scale_recording_\(Date().timeIntervalSince1970).m4a")
        
        print("Recording to: \(recordingURL?.path ?? "unknown")")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            // Create the audio recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            // Prepare to record
            guard audioRecorder?.prepareToRecord() ?? false else {
                print("❌ Failed to prepare recorder")
                return
            }
            
            print("✓ Recorder prepared")
            
            // Start recording
            let success = audioRecorder?.record() ?? false
            if success {
                isRecording = true
                print("✓ Recording started successfully")
                print("   Recorder is recording: \(audioRecorder?.isRecording ?? false)")
            } else {
                print("❌ Failed to start recording (record() returned false)")
            }
        } catch {
            print("❌ Failed to create audio recorder: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        print("🎙️ Stopping recording...")
        
        guard let recorder = audioRecorder, recorder.isRecording else {
            print("⚠️ No active recording to stop")
            return
        }
        
        recorder.stop()
        isRecording = false
        print("✓ Recording stopped")
        
        // Load the recorded audio data
        if let url = recordingURL {
            // Give a small delay to ensure file is written
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.loadRecordedAudio(from: url)
            }
        }
    }
    
    private func loadRecordedAudio(from url: URL) {
        do {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("❌ Recording file doesn't exist at path: \(url.path)")
                return
            }
            
            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            print("📁 Recording file size: \(fileSize) bytes")
            
            if fileSize < 1000 {
                print("⚠️ Warning: Recording file is very small (\(fileSize) bytes)")
            }
            
            recordedAudioData = try Data(contentsOf: url)
            print("✓ Audio data loaded: \(recordedAudioData?.count ?? 0) bytes")
        } catch {
            print("❌ Failed to load recorded audio: \(error)")
        }
    }
    
    func cleanup() {
        if isRecording {
            stopRecording()
        }
        
        // Clean up audio file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Cleaned up recording file")
        }
    }
    
    // MARK: - AVAudioRecorderDelegate
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✓ Recording finished successfully")
        } else {
            print("❌ Recording finished with error")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "unknown")")
    }
}
