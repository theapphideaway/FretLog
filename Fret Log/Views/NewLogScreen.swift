//
//  NewLogScreen.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/22/25.
//

import SwiftUI
import AVFoundation

struct NewLogScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = NewLogViewModel()
    
    @State private var selectedGenre: String = "Jazz"
    @State private var selectedPracticeType: String = "Improv"
    
    let genres = ["Jazz", "Classical"]
    let practiceTypes = ["Improv", "Song"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Practice Timer") {
                    VStack(spacing: 20) {
                        // Timer Display
                        Text(viewModel.formatElapsedTime(viewModel.elapsedTime))
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundColor(viewModel.isTimerRunning ? .green : .primary)
                        
                        // Start/Stop Button
                        Button(action: viewModel.toggleTimer) {
                            HStack {
                                Image(systemName: viewModel.isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(viewModel.isTimerRunning ? "Stop Practice" : "Start Practice")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isTimerRunning ? Color.red : Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Show session info when timer is running
                        if viewModel.isTimerRunning, let start = viewModel.startTime {
                            VStack(spacing: 4) {
                                Text("Session started at")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(viewModel.formatStartTime(start))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Practice Type") {
                    Picker("Practice Type", selection: $selectedPracticeType) {
                        ForEach(practiceTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Genre") {
                    Picker("Genre", selection: $selectedGenre) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Audio Recording") {
                    VStack(spacing: 16) {
                        // Recording Status
                        if viewModel.isRecording {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(viewModel.isRecording ? 1.0 : 0.5)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: viewModel.isRecording)
                                
                                Text("Recording...")
                                    .foregroundColor(.red)
                                    .font(.headline)
                                
                                Spacer()
                            }
                        }
                        
                        // Recording Success Indicator
                        if viewModel.recordedAudioData != nil && !viewModel.isRecording {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Audio recorded successfully")
                                    .foregroundColor(.green)
                                Spacer()
                            }
                        }
                        
                        // Record Button
                        Button(action: viewModel.toggleRecording) {
                            HStack {
                                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title2)
                                Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                            }
                            .foregroundColor(viewModel.isRecording ? .red : .blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.isRecording ? Color.red : Color.blue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Audio Playback Controls
                        if viewModel.recordedAudioData != nil && !viewModel.isRecording {
                            VStack(spacing: 12) {
                                // Play/Pause Button
                                Button(action: viewModel.togglePlayback) {
                                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                // Playback Controls
                                VStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { viewModel.playbackTime },
                                        set: { newValue in
                                            viewModel.seekAudio(to: newValue)
                                        }
                                    ), in: 0...max(viewModel.audioDuration, 0.1))
                                    .accentColor(.blue)
                                    
                                    // Time Labels
                                    HStack {
                                        Text(viewModel.formatTime(viewModel.playbackTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(viewModel.formatTime(viewModel.audioDuration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("New Practice Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cleanup()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let finalStartTime = viewModel.startTime ?? Date()
                        let finalEndTime = viewModel.isTimerRunning ?
                            Date() :
                            Date(timeIntervalSince1970: finalStartTime.timeIntervalSince1970 + viewModel.elapsedTime)
                        
                        viewModel.saveLogEntry(
                            startTime: finalStartTime,
                            endTime: finalEndTime,
                            genre: selectedGenre,
                            practiceType: selectedPracticeType
                        )
                        
                        viewModel.cleanup()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(viewModel.elapsedTime == 0)
                }
            }
            .onAppear {
                viewModel.setContext(viewContext)
            }
            .onDisappear {
                viewModel.cleanup()
            }
            .alert("Microphone Access Required", isPresented: $viewModel.showingPermissionAlert) {
                Button("Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to record audio during practice sessions.")
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    NewLogScreen()
}
