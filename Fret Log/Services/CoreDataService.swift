//
//  CoreDataService.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/29/25.
//

import Foundation
import CoreData

class CoreDataService {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Genre Methods
    func fetchOrCreateGenre(name: String) -> Genre {
        let request: NSFetchRequest<Genre> = Genre.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let newGenre = Genre(context: context)
        newGenre.name = name
        newGenre.created_at = Date()
        return newGenre
    }
    
    func getAllGenres() -> [Genre] {
        let request: NSFetchRequest<Genre> = Genre.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - PracticeType Methods
    func fetchOrCreatePracticeType(name: String) -> PracticeType {
        let request: NSFetchRequest<PracticeType> = PracticeType.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let newType = PracticeType(context: context)
        newType.name = name
        newType.created_at = Date()
        return newType
    }
    
    func getAllPracticeTypes() -> [PracticeType] {
        let request: NSFetchRequest<PracticeType> = PracticeType.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - GuitarLog Methods
    func createLog(
        startTime: Date,
        endTime: Date,
        genreNames: [String],
        practiceTypeNames: [String],
        audioFileName: String? = nil,
        audioFilePath: String? = nil
    ) throws -> GuitarLog {
        let log = GuitarLog(context: context)
        log.time_started = startTime
        log.time_ended = endTime
        log.audio_file_name = audioFileName
        log.audio_file_path = audioFilePath
        
        // Add genres
        var genreSet = Set<Genre>()
        for genreName in genreNames {
            genreSet.insert(fetchOrCreateGenre(name: genreName))
        }
        log.genres = genreSet as NSSet
        
        // Add practice types
        var typeSet = Set<PracticeType>()
        for typeName in practiceTypeNames {
            typeSet.insert(fetchOrCreatePracticeType(name: typeName))
        }
        log.practice_types = typeSet as NSSet
        
        try context.save()
        return log
    }
    
    func fetchLogs(withGenre genreName: String? = nil, withPracticeType typeName: String? = nil) -> [GuitarLog] {
        let request: NSFetchRequest<GuitarLog> = GuitarLog.fetchRequest()
        
        var predicates: [NSPredicate] = []
        if let genre = genreName {
            predicates.append(NSPredicate(format: "ANY genres.name == %@", genre))
        }
        if let type = typeName {
            predicates.append(NSPredicate(format: "ANY practiceTypes.name == %@", type))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "time_started", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
}

