//
//  NewLogViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/24/25.
//
//
//  NewLogViewModel.swift
//  Fret Log
//

import Foundation
import CoreData
import Combine

class NewLogViewModel: ObservableObject {
    @Published var errorMessage = ""
    @Published var selectedGenres: Set<String> = []
    @Published var selectedPracticeTypes: Set<String> = []
    
    let timerManager = TimerService()
    var audioManager = AudioService()
    private var dataManager: CoreDataService?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward published properties for convenience
        timerManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        audioManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }
    
    func setContext(_ context: NSManagedObjectContext) {
        self.dataManager = CoreDataService(context: context)
    }
    
    // MARK: - Genre & Practice Type Selection
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }
    
    func togglePracticeType(_ type: String) {
        if selectedPracticeTypes.contains(type) {
            selectedPracticeTypes.remove(type)
        } else {
            selectedPracticeTypes.insert(type)
        }
    }
    
    // MARK: - Save Log
    func saveLogEntry() {
        guard let dataManager = dataManager,
              let startTime = timerManager.startTime else {
            errorMessage = "Cannot save log without start time"
            return
        }
        
        let endTime = Date()
        
        // Save audio if exists
        var audioFileName: String?
        var audioFilePath: String?
        
        if let audioInfo = audioManager.saveAudioToFile() {
            audioFileName = audioInfo.fileName
            audioFilePath = audioInfo.filePath
        }
        
        // Validate selections
        guard !selectedGenres.isEmpty else {
            errorMessage = "Please select at least one genre"
            return
        }
        
        guard !selectedPracticeTypes.isEmpty else {
            errorMessage = "Please select at least one practice type"
            return
        }
        
        // Create log with relationships
        do {
            _ = try dataManager.createLog(
                startTime: startTime,
                endTime: endTime,
                genreNames: Array(selectedGenres),
                practiceTypeNames: Array(selectedPracticeTypes),
                audioFileName: audioFileName,
                audioFilePath: audioFilePath
            )
            
            // Reset after successful save
            reset()
        } catch {
            errorMessage = "Failed to save log: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Available Options
    func getAvailableGenres() -> [Genre] {
        return dataManager?.getAllGenres() ?? []
    }
    
    func getAvailablePracticeTypes() -> [PracticeType] {
        return dataManager?.getAllPracticeTypes() ?? []
    }
    
    // MARK: - Formatting
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
    
    // MARK: - Cleanup & Reset
    func reset() {
        timerManager.reset()
        audioManager.cleanup()
        selectedGenres.removeAll()
        selectedPracticeTypes.removeAll()
        errorMessage = ""
    }
    
    func cleanup() {
        timerManager.stop()
        audioManager.cleanup()
    }
}
