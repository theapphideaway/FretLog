//
//  NewLogViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/24/25.
//

import Foundation
import CoreData
import AVFoundation

class NewLogViewModel: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var errorMessage = ""
    @Published var audioFileName = ""
    @Published var audioFilePath = ""
    
    // Timer properties
    @Published var isTimerRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var startTime: Date?
    
    // Audio recording properties
    @Published var isRecording: Bool = false
    @Published var recordedAudioData: Data?
    @Published var showingPermissionAlert = false
    
    // Audio playback properties
    @Published var isPlaying: Bool = false
    @Published var playbackTime: TimeInterval = 0
    @Published var audioDuration: TimeInterval = 0
    
    private var context: NSManagedObjectContext?
    private var timer: Timer?
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    override init() {
        super.init()
        setupAudio()
    }
    
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Timer Functions
    func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        isTimerRunning = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = self.startTime {
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
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
    
    // MARK: - Audio Recording Functions
    func startRecording() {
        AVAudioApplication.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                if allowed {
                    self.beginRecording()
                } else {
                    self.showingPermissionAlert = true
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
            audioRecorder?.delegate = self
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
    
    // MARK: - Audio Playback Functions
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
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = self.audioPlayer {
                if player.isPlaying {
                    self.playbackTime = player.currentTime
                    
                    // Auto-stop when finished
                    if self.playbackTime >= self.audioDuration - 0.1 {
                        self.stopAudio()
                    }
                }
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // MARK: - Core Data Functions
    func addLog(log: GuitarLog) {
        guard let context = context else { return }
        do {
            try context.save()
        } catch {
            errorMessage = "Failed to Save Log: \(error.localizedDescription)"
        }
    }
    
    func saveAudioSample(_ audioData: Data, context: NSManagedObjectContext) {
        // Create unique filename
        let fileName = "practice_\(UUID().uuidString).m4a"
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first else { return }
        
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // Save audio file to documents directory
            try audioData.write(to: audioURL)
            
            // Save reference in Core Data
            self.audioFileName = fileName
            self.audioFilePath = audioURL.path
            
            try context.save()
        } catch {
            print("Error saving audio: \(error)")
        }
    }
    
    func saveLogEntry(startTime: Date, endTime: Date, genre: String, practiceType: String) {
        guard let context = context else { return }
        
        let log = GuitarLog(context: context)
        log.time_started = startTime
        log.time_ended = endTime
        log.genre = genre
        log.practice_type = practiceType
        
        if let audioData = recordedAudioData {
            saveAudioSample(audioData, context: context)
            log.audio_file_name = audioFileName
            log.audio_file_path = audioFilePath
        } else {
            log.audio_file_name = "No audio"
            log.audio_file_path = "No audio"
        }
        
        addLog(log: log)
    }
    
    func getAudioURL() -> URL? {
        let fileName = audioFileName
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first
        
        return documentsPath?.appendingPathComponent(fileName)
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopTimer()
        stopRecording()
        stopAudio()
    }
    
    // MARK: - Formatting Functions
    func formatElapsedTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    func formatStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}
