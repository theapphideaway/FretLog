//
//  ScaleValidatorPOC.swift
//  Fret Log
//
//  Proof of Concept for Scale Validation using Pitch Detection
//

import Foundation
import AVFoundation
import Accelerate



// MARK: - Scale Validator

class ScaleValidator {
    
    // MARK: - Configuration
    
    struct Config {
        var pitchTolerance: Double = 50.0 // cents (100 cents = 1 semitone)
        var minimumNoteDuration: TimeInterval = 0.2 // seconds
        var timingTolerance: TimeInterval = 2.0 // max time between notes
        var confidenceThreshold: Double = 0.6 // minimum confidence for note detection
        var passingAccuracy: Double = 0.75 // 75% of notes must be correct
    }
    
    let config: Config
    private var audioEngine: AVAudioEngine?
    
    init(config: Config = Config()) {
        self.config = config
    }
    
    // MARK: - Main Validation Method
    
    func validateScale(audioData: Data, expectedScale: [String]) async throws -> ScaleValidationResult {
        print("🎵 Starting scale validation...")
        print("Expected scale: \(expectedScale.joined(separator: ", "))")
        
        // Step 1: Extract audio samples from data
        let audioSamples = try extractAudioSamples(from: audioData)
        print("✓ Extracted \(audioSamples.count) audio samples")
        
        // Step 2: Detect pitches throughout the recording
        let detectedNotes = detectNotes(from: audioSamples, sampleRate: 44100.0)
        print("✓ Detected \(detectedNotes.count) notes")
        
        // Step 3: Clean up detected notes (remove duplicates, filter by confidence)
        let cleanedNotes = cleanDetectedNotes(detectedNotes)
        print("✓ Cleaned to \(cleanedNotes.count) distinct notes")
        
        // Step 4: Compare detected notes with expected scale
        let matchedNotes = compareNotes(detected: cleanedNotes, expected: expectedScale)
        print("✓ Matched notes: \(matchedNotes.filter { $0 }.count)/\(expectedScale.count)")
        
        // Step 5: Calculate accuracy and generate result
        let accuracy = Double(matchedNotes.filter { $0 }.count) / Double(expectedScale.count)
        let isValid = accuracy >= config.passingAccuracy
        
        let feedback = generateFeedback(
            detected: cleanedNotes,
            expected: expectedScale,
            matched: matchedNotes,
            accuracy: accuracy
        )
        
        return ScaleValidationResult(
            isValid: isValid,
            detectedNotes: cleanedNotes,
            expectedNotes: expectedScale,
            matchedNotes: matchedNotes,
            accuracy: accuracy,
            feedback: feedback
        )
    }
    
    // MARK: - Audio Processing
    
    private func extractAudioSamples(from data: Data) throws -> [Float] {
        // Create a unique temporary file URL
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        print("Writing audio data to: \(tempURL.path)")
        
        // Write the data to the file
        try data.write(to: tempURL)
        
        print("✓ Audio file written, size: \(data.count) bytes")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            print("❌ File doesn't exist after writing")
            throw ValidationError.audioProcessingFailed
        }
        
        // Open the audio file
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: tempURL)
            print("✓ Audio file opened successfully")
            print("   Format: \(audioFile.fileFormat)")
            print("   Duration: \(Double(audioFile.length) / audioFile.fileFormat.sampleRate) seconds")
        } catch {
            print("❌ Failed to open audio file: \(error)")
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            throw ValidationError.audioProcessingFailed
        }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create audio buffer")
            try? FileManager.default.removeItem(at: tempURL)
            throw ValidationError.audioProcessingFailed
        }
        
        do {
            try audioFile.read(into: buffer)
            print("✓ Read \(buffer.frameLength) frames from audio file")
        } catch {
            print("❌ Failed to read audio file: \(error)")
            try? FileManager.default.removeItem(at: tempURL)
            throw ValidationError.audioProcessingFailed
        }
        
        // Convert to Float array
        guard let floatData = buffer.floatChannelData else {
            print("❌ Failed to get float channel data")
            try? FileManager.default.removeItem(at: tempURL)
            throw ValidationError.audioProcessingFailed
        }
        
        let samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
        print("✓ Extracted \(samples.count) samples")
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        return samples
    }
    
    // MARK: - Pitch Detection (FFT-based)
    
    private func detectNotes(from samples: [Float], sampleRate: Double) -> [DetectedNote] {
        var detectedNotes: [DetectedNote] = []
        
        // FFT Configuration
        let fftSize = 4096
        let hopSize = 2048 // 50% overlap
        let windowCount = (samples.count - fftSize) / hopSize
        
        for i in 0..<windowCount {
            let startIndex = i * hopSize
            let endIndex = min(startIndex + fftSize, samples.count)
            
            guard endIndex - startIndex == fftSize else { continue }
            
            let window = Array(samples[startIndex..<endIndex])
            
            if let (frequency, confidence) = detectPitch(in: window, sampleRate: sampleRate) {
                if confidence >= config.confidenceThreshold {
                    let timestamp = Double(startIndex) / sampleRate
                    let noteName = frequencyToNote(frequency)
                    
                    detectedNotes.append(DetectedNote(
                        noteName: noteName,
                        frequency: frequency,
                        timestamp: timestamp,
                        confidence: confidence
                    ))
                }
            }
        }
        
        return detectedNotes
    }
    
    private func detectPitch(in samples: [Float], sampleRate: Double) -> (frequency: Double, confidence: Double)? {
        guard samples.count > 0 else { return nil }
        
        // Apply Hamming window
        var windowedSamples = samples
        var window = [Float](repeating: 0, count: samples.count)
        vDSP_hamm_window(&window, vDSP_Length(samples.count), 0)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(samples.count))
        
        // Perform FFT
        let log2n = vDSP_Length(log2(Float(samples.count)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var realParts = [Float](repeating: 0, count: samples.count / 2)
        var imaginaryParts = [Float](repeating: 0, count: samples.count / 2)
        
        windowedSamples.withUnsafeBufferPointer { samplesPtr in
            realParts.withUnsafeMutableBufferPointer { realPtr in
                imaginaryParts.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: samples.count / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(samples.count / 2))
                    }
                    
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                }
            }
        }
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: samples.count / 2)
        var splitComplexForMagnitude = DSPSplitComplex(realp: &realParts, imagp: &imaginaryParts)
        vDSP_zvabs(&splitComplexForMagnitude, 1, &magnitudes, 1, vDSP_Length(samples.count / 2))
        
        // Find peak frequency
        var maxValue: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(magnitudes.count))
        
        // Convert bin to frequency
        let frequency = Double(maxIndex) * sampleRate / Double(samples.count)
        
        // Calculate confidence (ratio of peak to average)
        var mean: Float = 0
        vDSP_meanv(magnitudes, 1, &mean, vDSP_Length(magnitudes.count))
        let confidence = min(Double(maxValue / (mean * 10)), 1.0)
        
        // Filter out frequencies outside guitar range (80 Hz - 1200 Hz)
        guard frequency >= 80 && frequency <= 1200 else {
            return nil
        }
        
        return (frequency, confidence)
    }
    
    // MARK: - Note Conversion
    
    private func frequencyToNote(_ frequency: Double) -> String {
        // A4 = 440 Hz
        let a4 = 440.0
        let c0 = a4 * pow(2, -4.75) // C0 frequency
        
        let halfSteps = 12 * log2(frequency / c0)
        let noteIndex = Int(round(halfSteps)) % 12
        let octave = Int(round(halfSteps)) / 12
        
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return "\(noteNames[noteIndex])\(octave)"
    }
    
    private func noteToFrequency(_ note: String) -> Double {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // Parse note (e.g., "C4", "F#3")
        var noteName = note
        var octaveStr = ""
        
        if let lastChar = note.last, lastChar.isNumber {
            octaveStr = String(lastChar)
            noteName = String(note.dropLast())
        }
        
        guard let noteIndex = noteNames.firstIndex(of: noteName),
              let octave = Int(octaveStr) else {
            return 0
        }
        
        let a4 = 440.0
        let c0 = a4 * pow(2, -4.75)
        let halfSteps = octave * 12 + noteIndex
        
        return c0 * pow(2, Double(halfSteps) / 12)
    }
    
    // MARK: - Note Cleaning
    
    private func cleanDetectedNotes(_ notes: [DetectedNote]) -> [DetectedNote] {
        guard !notes.isEmpty else { return [] }
        
        var cleanedNotes: [DetectedNote] = []
        var currentNote = notes[0]
        var noteStartTime = currentNote.timestamp
        
        for i in 1..<notes.count {
            let note = notes[i]
            
            // If same note continues, keep the current one
            if note.noteName == currentNote.noteName {
                continue
            }
            
            // Check if note was held long enough
            let noteDuration = note.timestamp - noteStartTime
            if noteDuration >= config.minimumNoteDuration {
                cleanedNotes.append(currentNote)
            }
            
            currentNote = note
            noteStartTime = note.timestamp
        }
        
        // Add the last note
        cleanedNotes.append(currentNote)
        
        return cleanedNotes
    }
    
    // MARK: - Note Comparison
    
    private func compareNotes(detected: [DetectedNote], expected: [String]) -> [Bool] {
        var matchedNotes = [Bool](repeating: false, count: expected.count)
        
        // Try to match detected notes to expected notes in order
        var detectedIndex = 0
        
        for (expectedIndex, expectedNote) in expected.enumerated() {
            guard detectedIndex < detected.count else { break }
            
            let detectedNote = detected[detectedIndex]
            
            if notesMatch(detectedNote.noteName, expectedNote) {
                matchedNotes[expectedIndex] = true
                detectedIndex += 1
            } else {
                // Allow skipping one detected note (in case of error)
                if detectedIndex + 1 < detected.count {
                    let nextDetectedNote = detected[detectedIndex + 1]
                    if notesMatch(nextDetectedNote.noteName, expectedNote) {
                        matchedNotes[expectedIndex] = true
                        detectedIndex += 2
                    } else {
                        detectedIndex += 1
                    }
                }
            }
        }
        
        return matchedNotes
    }
    
    private func notesMatch(_ detected: String, _ expected: String) -> Bool {
        // Compare note names (ignoring octave for now - could be made stricter)
        let detectedBase = detected.replacingOccurrences(of: "\\d", with: "", options: .regularExpression)
        let expectedBase = expected.replacingOccurrences(of: "\\d", with: "", options: .regularExpression)
        
        // Allow enharmonic equivalents (e.g., C# = Db)
        let enharmonicMap: [String: String] = [
            "C#": "Db", "Db": "C#",
            "D#": "Eb", "Eb": "D#",
            "F#": "Gb", "Gb": "F#",
            "G#": "Ab", "Ab": "G#",
            "A#": "Bb", "Bb": "A#"
        ]
        
        if detectedBase == expectedBase {
            return true
        }
        
        if let enharmonic = enharmonicMap[detectedBase], enharmonic == expectedBase {
            return true
        }
        
        return false
    }
    
    // MARK: - Feedback Generation
    
    private func generateFeedback(detected: [DetectedNote], expected: [String], matched: [Bool], accuracy: Double) -> String {
        var feedback = ""
        
        if accuracy >= config.passingAccuracy {
            feedback = "✅ Great job! You played the scale correctly.\n"
        } else {
            feedback = "❌ Keep practicing. You got \(Int(accuracy * 100))% of the notes correct.\n"
        }
        
        feedback += "\nDetected notes: \(detected.map { $0.noteName }.joined(separator: ", "))\n"
        feedback += "Expected notes: \(expected.joined(separator: ", "))\n\n"
        
        // Show which notes were correct/incorrect
        for (index, isMatched) in matched.enumerated() {
            let expectedNote = expected[index]
            let symbol = isMatched ? "✓" : "✗"
            feedback += "\(symbol) \(expectedNote)\n"
        }
        
        return feedback
    }
}
