//
//  LogDetailsViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/25/25.
//

import Foundation
import Combine
import CoreData
import AVFoundation

class LogDetailsViewModel: NSObject, ObservableObject {
    @Published var errorMessage = ""
    @Published var isPlaying = false
    @Published var playbackTime: TimeInterval = 0
    @Published var audioDuration: TimeInterval = 0
    @Published var audioLoaded = false
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Setup
    func setupAudio(audioPath: String) {
        guard audioPath != "No audio", !audioPath.isEmpty else {
            errorMessage = "No audio available"
            return
        }
        
        // Check if file exists at the path
        let fileURL = URL(fileURLWithPath: audioPath)
        
        if !FileManager.default.fileExists(atPath: audioPath) {
            // Try to construct path from filename if full path doesn't work
            if let fileName = audioPath.components(separatedBy: "/").last,
               let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let newURL = documentsPath.appendingPathComponent(fileName)
                setupAudioPlayer(url: newURL)
            } else {
                errorMessage = "Audio file not found"
                audioLoaded = false
            }
        } else {
            setupAudioPlayer(url: fileURL)
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            errorMessage = "Failed to setup audio session"
        }
    }
    
    private func setupAudioPlayer(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioDuration = audioPlayer?.duration ?? 0
            playbackTime = 0
            audioLoaded = true
            errorMessage = ""
        } catch {
            print("Failed to setup audio player: \(error)")
            errorMessage = "Failed to load audio file"
            audioLoaded = false
        }
    }
    
    // MARK: - Playback Controls
    func playAudio() {
        guard let player = audioPlayer, audioLoaded else { return }
        
        // Ensure playback goes through speaker
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("Failed to override audio output: \(error)")
        }
        
        player.play()
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
        audioPlayer?.currentTime = 0
        isPlaying = false
        playbackTime = 0
        stopPlaybackTimer()
    }
    
    func seekAudio(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        playbackTime = time
    }
    
    // MARK: - Timer Management
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
    
    deinit {
        stopAudio()
    }
    
    // MARK: - Formating
    func formatAudioTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func formatAudioDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
    
    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatDuration(log: GuitarLog) -> String {
        guard let start = log.time_started,
              let end = log.time_ended else { return "Unknown" }
        
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: View Helpers
    
    func hasAudio(log: GuitarLog) -> Bool {
        guard let audioFileName = log.audio_file_name else { return false }
        return audioFileName != "No audio" && !audioFileName.isEmpty
    }
    
    
}

// MARK: - AVAudioPlayerDelegate
extension LogDetailsViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTime = 0
            self.stopPlaybackTimer()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.errorMessage = "Audio decode error: \(error.localizedDescription)"
            }
            self.isPlaying = false
            self.audioLoaded = false
        }
    }
}
