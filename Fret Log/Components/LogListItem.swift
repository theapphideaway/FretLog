//
//  LogListItem.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/24/25.
//
import SwiftUI

struct LogListItem: View {
    let log: GuitarLog
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(practiceTypeColor)
                .frame(width: 4, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                // Practice Types and Genres as main content
                HStack {
                    // Display practice types
                    if !practiceTypeNames.isEmpty {
                        Text(practiceTypeNames.joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text("Practice")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if !genreNames.isEmpty {
                        Text("•")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(genreNames.joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Time information
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let duration = practiceLength {
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                if log.audio_file_name != "No audio" {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Show practice duration if available
                if let start = log.time_started, let end = log.time_ended {
                    let duration = end.timeIntervalSince(start)
                    if duration > 0 {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color("CardBackground"))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
    
    // Get primary practice type for color coding (uses first alphabetically)
    private var primaryPracticeType: String? {
        return practiceTypeNames.first
    }
    
    private var practiceTypeColor: Color {
        switch primaryPracticeType {
        case "Improv", "Improvisation": return .blue
        case "Technique": return .green
        case "Songs": return .orange
        case "Scales": return .purple
        case "Theory": return .pink
        case "Ear Training": return .teal
        default: return .gray
        }
    }
    
    private var dateString: String {
        guard let start = log.time_started else { return "" }
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(start) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: start))"
        } else if Calendar.current.isDateInYesterday(start) {
            formatter.timeStyle = .short
            return "Yesterday at \(formatter.string(from: start))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: start)
        }
    }
    
    private var practiceLength: String? {
        guard let start = log.time_started,
              let end = log.time_ended else { return nil }
        
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return nil }
        
        return formatDuration(duration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
