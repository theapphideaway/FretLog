//
//  Untitled.swift
//  Fret Log
//
//  Created by ian schoenrock on 10/7/25.
//

//
//  ScalePracticeScreen.swift
//  Fret Log
//
//  Scale Practice with Real-time Validation
//

import SwiftUI
import AVFoundation
import Accelerate

struct ScalePracticeScreen: View {
    @StateObject private var viewModel = ScalePracticeViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var recordingPulse = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Scale Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Select Scale")
                            .font(.headline)
                        
                        Picker("Scale", selection: $viewModel.selectedScaleIndex) {
                            ForEach(0..<viewModel.availableScales.count, id: \.self) { index in
                                Text(viewModel.availableScales[index].name)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Display the scale notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes to play:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(viewModel.currentScale.notes.enumerated()), id: \.offset) { index, note in
                                        Button(action: {
                                            viewModel.playNote(note)
                                        }) {
                                            VStack(spacing: 4) {
                                                Text(note)
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                
                                                if viewModel.currentlyPlayingNote == note {
                                                    Image(systemName: "speaker.wave.2.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(viewModel.currentlyPlayingNote == note ? Color.green : Color.blue)
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Play All Button
                            Button(action: {
                                viewModel.playAllNotes()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Play Full Scale")
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                    
                    // Recording Section
                    VStack(spacing: 16) {
                        // Large Recording Status Indicator
                        ZStack {
                            // Background pulse effect
                            if viewModel.isRecording {
                                Circle()
                                    .fill(Color.red.opacity(0.3))
                                    .frame(width: 150, height: 150)
                                    .scaleEffect(recordingPulse ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recordingPulse)
                                    .onAppear {
                                        recordingPulse = true
                                    }
                            }
                            
                            VStack(spacing: 12) {
                                // Recording indicator circle
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: viewModel.isRecording ? "waveform" : "mic.fill")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    )
                                
                                Text(viewModel.isRecording ? "Recording..." : "Ready to Record")
                                    .font(.headline)
                                    .foregroundColor(viewModel.isRecording ? .red : .secondary)
                            }
                        }
                        .frame(height: 150)
                        
                        // Instruction text
                        if !viewModel.isRecording && viewModel.validationResult == nil {
                            Text("Tap the button below to start recording, then play the scale")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Record/Stop Button
                        Button(action: {
                            if viewModel.isRecording {
                                recordingPulse = false
                                viewModel.stopRecordingAndValidate()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                    .font(.system(size: 28))
                                Text(viewModel.isRecording ? "Stop & Validate" : "Start Recording")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                                    .shadow(color: (viewModel.isRecording ? Color.red : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isValidating)
                    }
                    .padding()
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                    
                    // Validation Result
                    if viewModel.isValidating {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Analyzing your recording...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding()
                    } else if let result = viewModel.validationResult {
                        VStack(spacing: 20) {
                            // Big Pass/Fail Indicator
                            ZStack {
                                Circle()
                                    .fill(result.isValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: result.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(result.isValid ? .green : .red)
                            }
                            .padding()
                            
                            // Accuracy Score
                            VStack(spacing: 4) {
                                Text("Accuracy")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int(result.accuracy * 100))%")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(result.isValid ? .green : .orange)
                            }
                            
                            // Progress Bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 20)
                                    
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(result.isValid ? Color.green : Color.orange)
                                        .frame(width: geometry.size.width * result.accuracy, height: 20)
                                }
                            }
                            .frame(height: 20)
                            
                            Divider()
                            
                            // Detected vs Expected Notes
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Results")
                                    .font(.headline)
                                
                                // Expected Notes with Check/X marks
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(0..<result.expectedNotes.count, id: \.self) { index in
                                        HStack(spacing: 12) {
                                            Image(systemName: result.matchedNotes[index] ? "checkmark.circle.fill" : "xmark.circle.fill")
                                                .foregroundColor(result.matchedNotes[index] ? .green : .red)
                                                .font(.title3)
                                            
                                            Text(result.expectedNotes[index])
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                            
                                            if result.matchedNotes[index], index < result.detectedNotes.count {
                                                Text("→ \(result.detectedNotes[index].noteName)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Debug Info (Detected Notes)
                            if !result.detectedNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("All Detected Notes")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(result.detectedNotes.map { $0.noteName }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            
                            // Feedback Message
                            Text(result.feedback)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            // Try Again Button
                            Button("Try Again") {
                                viewModel.reset()
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color("CardBackground"))
                        .cornerRadius(16)
                        .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Scale Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        viewModel.cleanup()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $viewModel.audioManager.showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to record audio.")
            }
        }
    }
}
// MARK: - View Model



// MARK: - Note Player



// MARK: - Scale Model

struct Scale {
    let name: String
    let notes: [String]
}

// MARK: - Audio Recording Manager (simplified version)



#Preview {
    ScalePracticeScreen()
}

//
//  ScaleValidatorPOC.swift
//  Fret Log
//
//  Proof of Concept for Scale Validation using Pitch Detection
//



// MARK: - Note Detection Models

struct DetectedNote {
    let noteName: String
    let frequency: Double
    let timestamp: TimeInterval
    let confidence: Double
}

struct ScaleValidationResult {
    let isValid: Bool
    let detectedNotes: [DetectedNote]
    let expectedNotes: [String]
    let matchedNotes: [Bool] // parallel array showing which notes matched
    let accuracy: Double // percentage of correct notes
    let feedback: String
}

// MARK: - Scale Validator



// MARK: - Error Types

enum ValidationError: Error {
    case audioProcessingFailed
    case invalidAudioFormat
    case noAudioData
}

// MARK: - Test Scales

struct TestScales {
    static let cMajorScale = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
    static let gMajorScale = ["G3", "A3", "B3", "C4", "D4", "E4", "F#4", "G4"]
    static let aMinorScale = ["A3", "B3", "C4", "D4", "E4", "F4", "G4", "A4"]
    static let eMajorPentatonic = ["E3", "F#3", "G#3", "B3", "C#4", "E4"]
}

// MARK: - Usage Example

/*
 To test this POC:
 
 1. Record yourself playing a scale
 2. Save the audio data
 3. Run the validator:
 
 let validator = ScaleValidator()
 let result = try await validator.validateScale(
     audioData: recordedAudioData,
     expectedScale: TestScales.cMajorScale
 )
 
 print(result.feedback)
 print("Accuracy: \(result.accuracy * 100)%")
 print("Valid: \(result.isValid)")
 
 */
