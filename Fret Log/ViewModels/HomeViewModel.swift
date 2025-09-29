//
//  HomeViewModel.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/24/25.
//

import Foundation
import Combine
import CoreData

class HomeViewModel: ObservableObject{
    @Published var errorMessage = ""
    @Published var guitarLogs: [GuitarLog] = []
    
    private var context: NSManagedObjectContext?
        
    func setContext(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchLogs(){
        guard let context = context else { return }
        let request: NSFetchRequest<GuitarLog> = GuitarLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GuitarLog.time_ended, ascending: true)]
        
        do{
            guitarLogs = try context.fetch(request)
        } catch{
            errorMessage = "Failed to Fetch Logs: \(error.localizedDescription)"
        }
    }
    
    func addLog(log: GuitarLog){
        guard let context = context else { return }
        do{
            try context.save()
            fetchLogs()
        } catch{
            errorMessage = "Failed to Save Log: \(error.localizedDescription)"
        }
    }
}
