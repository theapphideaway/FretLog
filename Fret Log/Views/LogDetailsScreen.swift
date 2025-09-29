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
    @State private var practiceTypeColor: Color = .clear
    
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
                                // Display practice types
                                if !practiceTypeNames.isEmpty {
                                    Text(practiceTypeNames.joined(separator: ", "))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                } else {
                                    Text("Practice")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                
                                // Display genres
                                if !genreNames.isEmpty {
                                    Text(genreNames.joined(separator: ", "))
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Practice Types Section (as tags)
                        if !practiceTypeNames.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Practice Types")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(practiceTypeNames, id: \.self) { type in
                                        Text(type)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(getPracticeTypeColor(type))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        // Genres Section (as tags)
                        if !genreNames.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Genres")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(genreNames, id: \.self) { genre in
                                        Text(genre)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.secondary.opacity(0.15))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Session Details
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(title: "Date", value: viewModel.formatDate(log.time_started))
                            DetailRow(title: "Start Time", value: viewModel.formatTime(log.time_started))
                            DetailRow(title: "End Time", value: viewModel.formatTime(log.time_ended))
                            DetailRow(title: "Duration", value: viewModel.formatDuration(log: log))
                        }
                    }
                    .padding()
                    .background(Color("CardBackground"))
                    .cornerRadius(16)
                    
                    // Audio Section
                    if viewModel.hasAudio(log: log) {
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
                                            Text("Duration: \(viewModel.formatAudioDuration(viewModel.audioDuration))")
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
                                                Text(viewModel.formatAudioTime(viewModel.playbackTime))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Spacer()
                                                
                                                Text(viewModel.formatAudioTime(viewModel.audioDuration))
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
            if viewModel.hasAudio(log: log) {
                viewModel.setupAudio(audioPath: log.audio_file_path ?? "")
            }
            practiceTypeColor = primaryPracticeTypeColor
        }
        .onDisappear {
            viewModel.stopAudio()
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Computed Properties for Relationships
    
    private var practiceTypeNames: [String] {
        guard let types = log.practice_types as? Set<PracticeType> else { return [] }
        return types.compactMap { $0.name }.sorted()
    }
    
    private var genreNames: [String] {
        guard let genres = log.genres as? Set<Genre> else { return [] }
        return genres.compactMap { $0.name }.sorted()
    }
    
    private var primaryPracticeTypeColor: Color {
        guard let firstType = practiceTypeNames.first else { return .gray }
        return getPracticeTypeColor(firstType)
    }
    
    private func getPracticeTypeColor(_ type: String) -> Color {
        switch type {
        case "Improv", "Improvisation": return .blue
        case "Songs": return .orange
        case "Technique": return .green
        case "Scales": return .purple
        case "Theory": return .pink
        case "Ear Training": return .teal
        default: return .gray
        }
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

// MARK: - FlowLayout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
