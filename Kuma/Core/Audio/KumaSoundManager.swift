//
//  KumaSoundManager.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Singleton manager for playing custom Kuma notification sounds safely without deallocation issues.
//

import Foundation
import AVFoundation
import AppKit

public final class KumaSoundManager: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    public static let shared = KumaSoundManager()

    private var audioPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        syncCustomNotificationSoundToUserLibrary()
    }

    /// Ensures the custom notification sound is installed in ~/Library/Sounds/
    /// so macOS notification daemon (usernoted) can access and play it for native notifications.
    public func syncCustomNotificationSoundToUserLibrary() {
        guard let bundleSoundURL = Bundle.main.url(forResource: "kuma-alert", withExtension: "caf") else {
            return
        }

        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let userSoundsDirectory = homeDirectory.appendingPathComponent("Library/Sounds", isDirectory: true)
        let destinationURL = userSoundsDirectory.appendingPathComponent("kuma-alert.caf")

        do {
            if !fileManager.fileExists(atPath: userSoundsDirectory.path) {
                try fileManager.createDirectory(at: userSoundsDirectory, withIntermediateDirectories: true)
            }

            if fileManager.fileExists(atPath: destinationURL.path) {
                return // Sound is already installed, skip redundant disk I/O on startup
            }

            try fileManager.copyItem(at: bundleSoundURL, to: destinationURL)
        } catch {
            print("[KumaSoundManager] Could not sync sound to ~/Library/Sounds: \(error)")
        }
    }

    /// Plays the custom notification sound (`kuma-alert.caf`).
    public func playNotificationSound() {
        guard let soundURL = Bundle.main.url(forResource: "kuma-alert", withExtension: "caf") else {
            // Fallback to NSSound if file not in bundle
            NSSound(named: "Funk")?.play()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 0.45 // Standardized preview volume (~45%) for comfortable listening
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[KumaSoundManager] Failed to play notification sound: \(error)")
            NSSound(named: "Funk")?.play()
        }
    }

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player == audioPlayer {
            audioPlayer = nil
        }
    }
}
