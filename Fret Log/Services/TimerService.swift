//
//  TimerService.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/29/25.
//

import Foundation
import Combine

class TimerService: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var startTime: Date?
    
    private var timer: Timer?
    
    func start() {
        isRunning = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    func reset() {
        stop()
        elapsedTime = 0
        startTime = nil
    }
}
