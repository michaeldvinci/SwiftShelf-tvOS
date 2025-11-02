//
//  MediaPlayerControllerRepresentable.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 10/21/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct MediaPlayerControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        // Configure session for background audio
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.allowAirPlay, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            print("Failed to set AVAudioSession: \(error)")
        }
        
        // Set up delegate to handle dismissal
        controller.delegate = context.coordinator
        
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update the player if needed
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        let onDismiss: (() -> Void)?
        
        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            // Handle picture-in-picture end if needed
        }
        
        func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
            // Handle dismissal when PiP stops
            onDismiss?()
        }
    }
}

