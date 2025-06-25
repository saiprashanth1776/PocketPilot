//
//  CharacterControllerApp.swift
//  CharacterController
//
//  Created by Prashanth on 6/23/25.
//

import SwiftUI
import Foundation
import UIKit

class WebSocketClient: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    private let url: URL
    private let session: URLSession
    
    init(url: URL) {
        self.url = url
        self.session = URLSession(configuration: .default)
        connect()
    }
    
    func connect() {
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }
    
    func send(_ message: String) {
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(wsMessage) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func receive() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
            case .success(let message):
                print("Received: \(message)")
            }
            self?.receive()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}

@main
struct CharacterControllerApp: App {
    // Lock orientation to landscape
    init() {
        AppDelegate.orientationLock = .landscape
    }
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.landscape
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
