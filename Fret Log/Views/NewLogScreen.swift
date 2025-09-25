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
    
    @State private var selectedGenre: String = "Jazz"
    @State private var selectedPracticeType: String = "Improv"
    @State private var isRecording: Bool = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordedAudioData: Data?
    @State private var showingPermissionAlert = false
    
    // Audio playback states
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var playbackTime: TimeInterval = 0
    @State private var audioDuration: TimeInterval = 0
    @State private var playbackTimer: Timer?
    
    // Timer states
    @State private var isTimerRunning: Bool = false
    @State private var startTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    
    let genres = ["Jazz", "Classical"]
    let practiceTypes = ["Improv", "Song"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Practice Timer") {
                    VStack(spacing: 20) {
                        // Timer Display
                        Text(formatElapsedTime(elapsedTime))
                            .font(.system(size: 48, weight: .light, design: .monospaced))
                            .foregroundColor(isTimerRunning ? .green : .primary)
                        
                        // Start/Stop Button
                        Button(action: toggleTimer) {
                            HStack {
                                Image(systemName: isTimerRunning ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                Text(isTimerRunning ? "Stop Practice" : "Start Practice")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isTimerRunning ? Color.red : Color.green)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Show session info when timer is running
                        if isTimerRunning, let start = startTime {
                            VStack(spacing: 4) {
                                Text("Session started at")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatStartTime(start))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Practice Type") {
                    Picker("Practice Type", selection: $selectedPracticeType) {
                        ForEach(practiceTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Genre") {
                    Picker("Genre", selection: $selectedGenre) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Audio Recording") {
                    VStack(spacing: 16) {
                        if isRecording {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                    .scaleEffect(isRecording ? 1.0 : 0.5)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: isRecording)
                                
                                Text("Recording...")
                                    .foregroundColor(.red)
                                    .font(.headline)
                                
                                Spacer()
                            }
                        }
                        
                        if recordedAudioData != nil && !isRecording {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Audio recorded successfully")
                                    .foregroundColor(.green)
                                Spacer()
                            }
                        }
                        
                        Button(action: {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            HStack {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.title2)
                                Text(isRecording ? "Stop Recording" : "Start Recording")
                            }
                            .foregroundColor(isRecording ? .red : .blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isRecording ? Color.red : Color.blue, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        
                        if recordedAudioData != nil && !isRecording {
                            VStack(spacing: 12) {
                                
                                Button(action: {
                                    if isPlaying {
                                        pauseAudio()
                                    } else {
                                        playAudio()
                                    }
                                }) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                
                                VStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { playbackTime },
                                        set: { newValue in
                                            seekAudio(to: newValue)
                                        }
                                    ), in: 0...max(audioDuration, 0.1))
                                    .accentColor(.blue)
                                    
                                    
                                    HStack {
                                        Text(formatTime(playbackTime))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text(formatTime(audioDuration))
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
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationTitle("New Practice Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        stopTimer()
                        stopRecording()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let finalStartTime = startTime ?? Date()
                        let finalEndTime = isTimerRunning ? Date() : Date(timeIntervalSince1970: finalStartTime.timeIntervalSince1970 + elapsedTime)
                        
                        saveLogEntry(startTime: finalStartTime, endTime: finalEndTime)
                        
                        stopTimer()
                        stopRecording()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(elapsedTime == 0)
                }
            }
            .onAppear {
                viewModel.setContext(viewContext)
                setupAudio()
            }
            .onDisappear {
                stopTimer()
                stopRecording()
                stopAudio()
            }
            .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
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
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Timer Functions
    private func toggleTimer() {
        if isTimerRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        isTimerRunning = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = startTime {
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Audio Recording Functions
    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func startRecording() {
        
        AVAudioApplication.requestRecordPermission { allowed in
            DispatchQueue.main.async {
                if allowed {
                    self.beginRecording()
                } else {
                    self.showingPermissionAlert = true
                }
            }
        }
    }
    
    private func beginRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("temp_recording.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = viewModel as? AVAudioRecorderDelegate
            audioRecorder?.record()
            
            isRecording = true
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        
        if let audioRecorder = audioRecorder {
            do {
                let audioData = try Data(contentsOf: audioRecorder.url)
                recordedAudioData = audioData
                setupAudioPlayer()
            } catch {
                print("Failed to load audio data: \(error)")
            }
        }
    }
    
    // MARK: - Save Function
    private func saveLogEntry(startTime: Date, endTime: Date) {
        let log = GuitarLog(context: viewContext)
        log.time_started = startTime
        log.time_ended = endTime
        log.genre = selectedGenre
        log.practice_type = selectedPracticeType
        
        if let audioData = recordedAudioData {
            viewModel.saveAudioSample(audioData, context: viewContext)
            log.audio_file_name = viewModel.audioFileName
            log.audio_file_path = viewModel.audioFilePath
        } else {
            log.audio_file_name = "No audio"
            log.audio_file_path = "No audio"
        }
        
        viewModel.addLog(log: log)
    }
    
    // MARK: - Formatting Functions
    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatStartTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func setupAudioPlayer() {
        guard let audioRecorder = audioRecorder else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioRecorder.url)
            audioDuration = audioPlayer?.duration ?? 0
            playbackTime = 0
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }

    private func playAudio() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }

    private func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    private func stopAudio() {
        audioPlayer?.stop()
        isPlaying = false
        playbackTime = 0
        stopPlaybackTimer()
    }

    private func seekAudio(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        playbackTime = time
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = audioPlayer {
                if player.isPlaying {
                    playbackTime = player.currentTime
                    
                    // Auto-stop when finished
                    if playbackTime >= audioDuration - 0.1 {
                        stopAudio()
                    }
                }
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NewLogScreen()
}
