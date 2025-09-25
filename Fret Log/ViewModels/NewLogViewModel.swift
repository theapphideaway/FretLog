//
//  NewLogViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/24/25.
//

import Foundation
import Combine
import CoreData

class NewLogViewModel: ObservableObject{
    @Published var errorMessage = ""
    @Published var audioFileName = ""
    @Published var audioFilePath = ""
    
    private var context: NSManagedObjectContext?
        
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    func addLog(log: GuitarLog){
        guard let context = context else { return }
        do{
            try context.save()
        } catch{
            errorMessage = "Failed to Save Log: \(error.localizedDescription)"
        }
    }
    
    func saveAudioSample(_ audioData: Data, context: NSManagedObjectContext) {
        // Create unique filename
        let fileName = "practice_\(UUID().uuidString).m4a"
        
        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first else { return }
        
        let audioURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            // Save audio file to documents directory
            try audioData.write(to: audioURL)
            
            // Save reference in Core Data
            self.audioFileName = fileName
            self.audioFilePath = audioURL.path
            
            try context.save()
        } catch {
            print("Error saving audio: \(error)")
        }
    }
    
    func getAudioURL() -> URL? {
        let fileName = audioFileName
        let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first
        
        return documentsPath?.appendingPathComponent(fileName)
    }
}
