//
//  ScalePracticeViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 10/7/25.
//


import SwiftUI
import Combine

class ScalePracticeViewModel: ObservableObject {
    @Published var audioManager = AudioRecordingManager()
    @Published var validationResult: ScaleValidationResult?
    @Published var isValidating = false
    @Published var selectedScaleIndex = 0
    @Published var currentlyPlayingNote: String?
    @Published var isRecording = false  // Add this to track recording state
    
    private let notePlayer = NotePlayer()
    private var cancellables = Set<AnyCancellable>()
    
    let availableScales: [Scale] = [
        Scale(name: "C Major", notes: ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]),
        Scale(name: "G Major", notes: ["G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4"]),
        Scale(name: "A Minor", notes: ["A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4"]),
        Scale(name: "E Major Pentatonic", notes: ["E3", "F#3", "G#3", "B3", "C#4", "E4"]),
        Scale(name: "A Minor Pentatonic", notes: ["A3", "C4", "D4", "E4", "G4", "A4"])
    ]
    
    var currentScale: Scale {
        availableScales[selectedScaleIndex]
    }
    
    private let validator = ScaleValidator()
    
    init() {
        // Subscribe to audioManager's isRecording changes
        audioManager.$isRecording
            .sink { [weak self] recording in
                self?.isRecording = recording
                print("📱 ViewModel isRecording updated to: \(recording)")
            }
            .store(in: &cancellables)
    }
    
    func startRecording() {
        validationResult = nil
        notePlayer.stop() // Stop any playing notes
        audioManager.startRecording()
    }
    
    func stopRecordingAndValidate() {
        audioManager.stopRecording()
        
        // Give a moment for recording to finalize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.validateRecording()
        }
    }
    
    func playNote(_ note: String) {
        currentlyPlayingNote = note
        notePlayer.playNote(note) { [weak self] in
            DispatchQueue.main.async {
                self?.currentlyPlayingNote = nil
            }
        }
    }
    
    func playAllNotes() {
        notePlayer.playScale(currentScale.notes) { [weak self] playingNote in
            DispatchQueue.main.async {
                self?.currentlyPlayingNote = playingNote
            }
        }
    }
        
    func validateRecording() {
        guard let audioData = audioManager.recordedAudioData else {
            print("No audio data to validate")
            return
        }
        
        isValidating = true
        
        Task {
            do {
                let result = try await validator.validateScale(
                    audioData: audioData,
                    expectedScale: currentScale.notes
                )
                
                await MainActor.run {
                    self.validationResult = result
                    self.isValidating = false
                }
            } catch {
                print("Validation error: \(error)")
                await MainActor.run {
                    self.isValidating = false
                }
            }
        }
    }
    
    func reset() {
        validationResult = nil
        audioManager.recordedAudioData = nil
    }
    
    func cleanup() {
        audioManager.cleanup()
        notePlayer.stop()
    }
}
