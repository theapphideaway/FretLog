//
//  NotePlayer.swift
//  Fret Log
//
//  Audio playback for individual notes and scales
//

import Foundation
import AVFoundation

class NotePlayer {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isPlaying = false
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Set category to playback so it plays through speakers
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✓ Audio session configured for playback")
        } catch {
            print("❌ Failed to set up audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        
        // Use a standard format for tone generation
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            print("✓ Audio engine started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    func playNote(_ note: String, completion: (() -> Void)? = nil) {
        print("🎵 Playing note: \(note)")
        stop() // Stop any currently playing note
        
        let frequency = noteToFrequency(note)
        print("   Frequency: \(frequency) Hz")
        let duration: TimeInterval = 0.8 // seconds
        
        playTone(frequency: frequency, duration: duration, completion: completion)
    }
    
    func playScale(_ notes: [String], onNoteChange: @escaping (String?) -> Void) {
        stop()
        
        var currentIndex = 0
        
        func playNext() {
            guard currentIndex < notes.count else {
                onNoteChange(nil)
                return
            }
            
            let note = notes[currentIndex]
            onNoteChange(note)
            
            let frequency = noteToFrequency(note)
            playTone(frequency: frequency, duration: 0.6) {
                currentIndex += 1
                // Small pause between notes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    playNext()
                }
            }
        }
        
        playNext()
    }
    
    private func playTone(frequency: Double, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let engine = audioEngine, let player = playerNode else {
            print("❌ Audio engine or player node is nil")
            completion?()
            return
        }
        
        // Ensure engine is running
        if !engine.isRunning {
            do {
                try engine.start()
                print("✓ Restarted audio engine")
            } catch {
                print("❌ Failed to restart engine: \(error)")
                completion?()
                return
            }
        }
        
        let sampleRate = 44100.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // Use standard mono format for tone generation
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("❌ Failed to create audio format")
            completion?()
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create audio buffer")
            completion?()
            return
        }
        
        buffer.frameLength = frameCount
        
        // Generate sine wave
        guard let channelData = buffer.floatChannelData else {
            print("❌ Failed to get channel data")
            completion?()
            return
        }
        
        let channelBuffer = channelData[0] // Mono, so just use first channel
        
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let amplitude = Float(0.25) // Volume (0.0 to 1.0)
            
            // Apply envelope (fade in/out) for smoother sound
            let fadeTime = 0.05
            var envelope: Float = 1.0
            if time < fadeTime {
                envelope = Float(time / fadeTime)
            } else if time > duration - fadeTime {
                envelope = Float((duration - time) / fadeTime)
            }
            
            let sample = amplitude * envelope * Float(sin(2.0 * Double.pi * frequency * time))
            channelBuffer[frame] = sample
        }
        
        isPlaying = true
        print("✓ Scheduling audio buffer")
        
        player.scheduleBuffer(buffer) {
            self.isPlaying = false
            print("✓ Buffer playback completed")
            DispatchQueue.main.async {
                completion?()
            }
        }
        
        if !player.isPlaying {
            player.play()
            print("✓ Started player node")
        }
    }
    
    func stop() {
        playerNode?.stop()
        isPlaying = false
    }
    
    private func noteToFrequency(_ note: String) -> Double {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // Parse note (e.g., "C4", "F#3")
        var noteName = note
        var octaveStr = ""
        
        if let lastChar = note.last, lastChar.isNumber {
            octaveStr = String(lastChar)
            noteName = String(note.dropLast())
        }
        
        guard let noteIndex = noteNames.firstIndex(of: noteName),
              let octave = Int(octaveStr) else {
            return 440.0 // Default to A4
        }
        
        let a4 = 440.0
        let c0 = a4 * pow(2, -4.75)
        let halfSteps = octave * 12 + noteIndex
        
        return c0 * pow(2, Double(halfSteps) / 12)
    }
}
