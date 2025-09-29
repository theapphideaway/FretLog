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
    
    @State private var selectedGenres: Set<String> = []
    @State private var selectedPracticeTypes: Set<String> = []
    
    let genres = ["Jazz", "Classical", "Rock", "Blues", "Folk", "Metal"]
    let practiceTypes = ["Improv", "Songs", "Scales", "Technique", "Theory", "Ear Training"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 20) {
                        // Timer Display
                        Text(viewModel.formatElapsedTime(viewModel.timerManager.elapsedTime))
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundColor(viewModel.timerManager.isRunning ? .green : .primary)
                        
                        // Start/Stop Button
                        Button(action: {
                            viewModel.timerManager.toggle()
                        }) {
                            HStack {
                                Image(systemName: viewModel.timerManager.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(viewModel.timerManager.isRunning ? "Stop Practice" : "Start Practice")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.timerManager.isRunning ? Color.red : Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Show session info when timer is running
                        if viewModel.timerManager.isRunning, let start = viewModel.timerManager.startTime {
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
                } header: {
                    Text("Practice Timer")
                }
                
                Section {
                    ForEach(practiceTypes, id: \.self) { type in
                        HStack {
                            Image(systemName: selectedPracticeTypes.contains(type) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPracticeTypes.contains(type) ? .blue : .gray)
                            Text(type)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            togglePracticeType(type)
                        }
                    }
                } header: {
                    Text("Practice Types")
                } footer: {
                    Text("Select one or more practice types")
                }
                
                Section {
                    ForEach(genres, id: \.self) { genre in
                        HStack {
                            Image(systemName: selectedGenres.contains(genre) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedGenres.contains(genre) ? .blue : .gray)
                            Text(genre)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleGenre(genre)
                        }
                    }
                } header: {
                    Text("Genres")
                } footer: {
                    Text("Select one or more genres")
                }
                
                Section {
                    VStack(spacing: 16) {
                        // Recording Status
                        if viewModel.audioManager.isRecording {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(viewModel.audioManager.isRecording ? 1.0 : 0.5)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: viewModel.audioManager.isRecording)
                                
                                Text("Recording...")
                                    .foregroundColor(.red)
                                    .font(.headline)
                                
                                Spacer()
                            }
                        }
                        
                        // Recording Success Indicator
                        if viewModel.audioManager.recordedAudioData != nil && !viewModel.audioManager.isRecording {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Audio recorded successfully")
                                    .foregroundColor(.green)
                                Spacer()
                            }
                        }
                        
                        // Record Button
                        Button(action: {
                            viewModel.audioManager.toggleRecording()
                        }) {
                            HStack {
                                Image(systemName: viewModel.audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title2)
                                Text(viewModel.audioManager.isRecording ? "Stop Recording" : "Start Recording")
                            }
                            .foregroundColor(viewModel.audioManager.isRecording ? .red : .blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.audioManager.isRecording ? Color.red : Color.blue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Audio Playback Controls
                        if viewModel.audioManager.recordedAudioData != nil && !viewModel.audioManager.isRecording {
                            VStack(spacing: 12) {
                                // Play/Pause Button
                                Button(action: {
                                    viewModel.audioManager.togglePlayback()
                                }) {
                                    Image(systemName: viewModel.audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                // Playback Controls
                                VStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { viewModel.audioManager.playbackTime },
                                        set: { newValue in
                                            viewModel.audioManager.seekAudio(to: newValue)
                                        }
                                    ), in: 0...max(viewModel.audioManager.audioDuration, 0.1))
                                    .accentColor(.blue)
                                    
                                    // Time Labels
                                    HStack {
                                        Text(viewModel.formatTime(viewModel.audioManager.playbackTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(viewModel.formatTime(viewModel.audioManager.audioDuration))
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
                } header: {
                    Text("Audio Recording")
                }
            }
            .navigationTitle("New Practice Log")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cleanup()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveLog()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                viewModel.setContext(viewContext)
            }
            .onDisappear {
                viewModel.cleanup()
            }
            .alert("Microphone Access Required", isPresented: $viewModel.audioManager.showingPermissionAlert) {
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
    }
    
    // MARK: - Helper Functions
    
    private func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }
    
    private func togglePracticeType(_ type: String) {
        if selectedPracticeTypes.contains(type) {
            selectedPracticeTypes.remove(type)
        } else {
            selectedPracticeTypes.insert(type)
        }
    }
    
    private var canSave: Bool {
        viewModel.timerManager.elapsedTime > 0 &&
        !selectedGenres.isEmpty &&
        !selectedPracticeTypes.isEmpty
    }
    
    private func saveLog() {
        viewModel.selectedGenres = selectedGenres
        viewModel.selectedPracticeTypes = selectedPracticeTypes
        
        viewModel.saveLogEntry()
        viewModel.cleanup()
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NewLogScreen()
}
