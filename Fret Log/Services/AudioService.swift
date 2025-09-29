//
//  AudioService.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/29/25.
//

//
//  AudioManager.swift
//  Fret Log
//

import Foundation
import AVFoundation
import Combine

class AudioService: NSObject, ObservableObject {
    // Recording properties
    @Published var isRecording: Bool = false
    @Published var recordedAudioData: Data?
    @Published var showingPermissionAlert = false
    
    // Playback properties
    @Published var isPlaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var audioDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    override init() {
        super.init()
        setupAudio()
    }
    
    // MARK: - Audio Setup
    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Recording
    func startRecording() {
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self?.beginRecording()
                } else {
                    self?.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func beginRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("temp_recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let audioRecorder = audioRecorder {
            do {
                let audioData = try Data(contentsOf: audioRecorder.url)
                recordedAudioData = audioData
                setupAudioPlayer()
            } catch {
                print("Failed to load audio data: \(error)")
            }
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // MARK: - Playback
    private func setupAudioPlayer() {
        guard let audioRecorder = audioRecorder else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioRecorder.url)
            audioDuration = audioPlayer?.duration ?? 0
            playbackTime = 0
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }
    
    func playAudio() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
        playbackTime = 0
        audioPlayer?.currentTime = 0
        stopPlaybackTimer()
    }
    
    func seekAudio(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        playbackTime = time
    }
    
    func togglePlayback() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            
            if player.isPlaying {
                self.playbackTime = player.currentTime
                
                if self.playbackTime >= self.audioDuration - 0.1 {
                    self.stopAudio()
                }
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - File Management
    func saveAudioToFile() -> (fileName: String, filePath: String)? {
        guard let audioData = recordedAudioData else { return nil }
        
        let fileName = "practice_\(UUID().uuidString).m4a"
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try audioData.write(to: audioURL)
            return (fileName: fileName, filePath: audioURL.path)
        } catch {
            print("Error saving audio: \(error)")
            return nil
        }
    }
    
    func loadAudioFromFile(fileName: String) {
        guard let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return }
        
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioDuration = audioPlayer?.duration ?? 0
            playbackTime = 0
        } catch {
            print("Failed to load audio file: \(error)")
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopRecording()
        stopAudio()
    }
}
