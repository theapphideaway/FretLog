//
//  LogDetailsScreen.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/22/25.
//

import SwiftUI
import AVFoundation

struct LogDetailsScreen: View {
    let log: GuitarLog
    @StateObject private var viewModel = LogDetailsViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(practiceTypeColor)
                                .frame(width: 6, height: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.practice_type ?? "Practice")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(log.genre ?? "")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Session Details
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(title: "Date", value: formatDate(log.time_started))
                            DetailRow(title: "Start Time", value: formatTime(log.time_started))
                            DetailRow(title: "End Time", value: formatTime(log.time_ended))
                            DetailRow(title: "Duration", value: formatDuration())
                        }
                    }
                    .padding()
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                    
                    // Audio Section
                    if hasAudio {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recording")
                                .font(.headline)
                            
                            VStack(spacing: 16) {
                                // Waveform Icon and Status
                                HStack {
                                    Image(systemName: "waveform")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Practice Recording")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        if viewModel.audioDuration > 0 {
                                            Text("Duration: \(formatAudioDuration(viewModel.audioDuration))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                
                                // Audio Player Controls
                                VStack(spacing: 12) {
                                    // Play/Pause Button
                                    Button(action: {
                                        if viewModel.isPlaying {
                                            viewModel.pauseAudio()
                                        } else {
                                            viewModel.playAudio()
                                        }
                                    }) {
                                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!viewModel.audioLoaded)
                                    
                                    // Progress Bar
                                    if viewModel.audioLoaded {
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
                                                Text(formatAudioTime(viewModel.playbackTime))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                Text(formatAudioTime(viewModel.audioDuration))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    // Error or Loading State
                                    if !viewModel.errorMessage.isEmpty {
                                        Text(viewModel.errorMessage)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    } else if !viewModel.audioLoaded {
                                        Text("Loading audio...")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color("CardBackground"))
                        .cornerRadius(16)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Practice Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.stopAudio()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if hasAudio {
                viewModel.setupAudio(audioPath: log.audio_file_path ?? "")
            }
        }
        .onDisappear {
            viewModel.stopAudio()
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Helper Properties
    private var hasAudio: Bool {
        guard let audioFileName = log.audio_file_name else { return false }
        return audioFileName != "No audio" && !audioFileName.isEmpty
    }
    
    private var practiceTypeColor: Color {
        switch log.practice_type {
        case "Improv": return .blue
        case "Song": return .orange
        case "Technique": return .green
        case "Scales": return .purple
        case "Theory": return .pink
        case "Ear Training": return .teal
        default: return .gray
        }
    }
    
    // MARK: - Formatting Functions
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration() -> String {
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
    
    private func formatAudioTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatAudioDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}


