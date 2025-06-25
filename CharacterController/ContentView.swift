//
//  ContentView.swift
//  CharacterController
//
//  Created by Prashanth on 6/23/25.
//

import SwiftUI
import CocoaMQTT

// Set your MQTT broker address and topic here:
let MQTT_BROKER_HOST = "broker.emqx.io"
let MQTT_BROKER_PORT: UInt16 = 1883
let MQTT_TOPIC = "mycontroller/controls"

// Add this enum at the top-level (outside any struct/class)
enum ControlType {
    case left, right, slider
}

class MQTTManager: NSObject, ObservableObject, CocoaMQTTDelegate {
    var mqtt: CocoaMQTT?
    @Published var isConnected: Bool = false

    override init() {
        super.init()
        connect()
    }

    func connect() {
        let clientID = "iOSController-\(UUID().uuidString.prefix(6))"
        mqtt = CocoaMQTT(clientID: clientID, host: MQTT_BROKER_HOST, port: MQTT_BROKER_PORT)
        mqtt?.delegate = self
        mqtt?.autoReconnect = true
        mqtt?.connect()
    }

    func send(jsonString: String) {
        mqtt?.publish(MQTT_TOPIC, withString: jsonString)
    }

    // MARK: - CocoaMQTTDelegate (v2.x required stubs)
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("Connected to MQTT broker!")
        isConnected = true
    }
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Published message: \(message.string ?? "")")
    }
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    func mqttDidPing(_ mqtt: CocoaMQTT) {}
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        print("Disconnected from MQTT broker")
        isConnected = false
    }
    // Optional methods for SSL/TLS and state changes
    func mqtt(_ mqtt: CocoaMQTT, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) { completionHandler(true) }
    func mqtt(_ mqtt: CocoaMQTT, didPublishComplete id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {}
}

struct ControlPanelView: View {
    @StateObject private var mqttManager = MQTTManager()
    @State private var leftPadOffset: CGSize = .zero
    @State private var rightPadOffset: CGSize = .zero
    @State private var leftPadLastValue: CGSize = .zero
    @State private var rightPadLastValue: CGSize = .zero
    @State private var sliderY: CGFloat? = nil
    @State private var scaleValue: Double = 0 // For horizontal slider
    
    private func sendButtonCommand(_ command: String) {
        let json: [String: Any] = ["button": command]
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            mqttManager.send(jsonString: str)
        }
    }
    
    private func sendThrustCommand() {
        let json: [String: Any] = ["thrust": true]
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            mqttManager.send(jsonString: str)
        }
    }

    private func sendCloakCommand() {
        let json: [String: Any] = ["cloak": true]
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            mqttManager.send(jsonString: str)
        }
    }
    
    private func sendResetCommand() {
        let json: [String: Any] = ["reset": true]
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            mqttManager.send(jsonString: str)
        }
        
        // Reset slider to middle position
        sliderY = nil // This will make the slider return to center (value 0)
    }
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let leftWidth = totalWidth * 0.4
            let middleWidth = totalWidth * 0.4
            let rightWidth = totalWidth * 0.2
            let joystickSize = min(leftWidth, totalHeight)
            let redJoystickSize = min(middleWidth, totalHeight * 0.6)
            let buttonSize = min(middleWidth * 0.5, totalHeight * 0.18)
            let sliderHeight = totalHeight * 0.8
            let spacing = totalWidth * 0.04
            HStack {
                // Left: Blue joystick
                VStack {
                    TouchPadView(
                        color: .blue,
                        accessibilityPrefix: "Left Pad",
                        dragOffset: $leftPadOffset,
                        lastValue: $leftPadLastValue,
                        onUpdate: { offset, last in
                            sendControlUpdate(left: last, right: rightPadLastValue, sliderY: sliderY, padSize: joystickSize, sliderHeight: joystickSize, changed: .left)
                        },
                        padSize: joystickSize,
                        onRelease: {
                            sendControlUpdate(left: .zero, right: rightPadLastValue, sliderY: sliderY, padSize: joystickSize, sliderHeight: joystickSize, changed: .left)
                        }
                    )
                    .frame(width: joystickSize, height: joystickSize)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer().frame(width: 50)

                // Middle: Red joystick + buttons
                VStack {
                    Spacer().frame(height: 20)
                    TouchPadView(
                        color: .red,
                        accessibilityPrefix: "Right Pad",
                        dragOffset: $rightPadOffset,
                        lastValue: $rightPadLastValue,
                        onUpdate: { offset, last in
                            sendControlUpdate(left: leftPadLastValue, right: last, sliderY: sliderY, padSize: redJoystickSize, sliderHeight: redJoystickSize, changed: .right)
                        },
                        padSize: redJoystickSize,
                        onRelease: {
                            sendControlUpdate(left: leftPadLastValue, right: .zero, sliderY: sliderY, padSize: redJoystickSize, sliderHeight: redJoystickSize, changed: .right)
                        }
                    )
                    .frame(width: redJoystickSize, height: redJoystickSize)
                    Spacer().frame(height: redJoystickSize * 0.10)
                    HStack(spacing: middleWidth * 0.08) {
                        Button(action: {
                            sendThrustCommand()
                        }) {
                            Circle()
                                .fill(Color.green.opacity(0.85))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        Button(action: {
                            sendCloakCommand()
                        }) {
                            Circle()
                                .fill(Color.purple.opacity(0.85))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                        Button(action: {
                            sendResetCommand()
                        }) {
                            Circle()
                                .fill(Color.orange.opacity(0.85))
                                .frame(width: buttonSize, height: buttonSize)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer().frame(width: 50)

                // Right: Vertical yellow slider
                VStack {
                    VerticalSlider(
                        value: Binding(
                            get: {
                                Double(sliderY ?? 0)
                            },
                            set: { newValue in
                                sliderY = CGFloat(newValue)
                                // Send slider value as soon as it changes
                                let json: [String: Any] = ["slider": newValue]
                                if let data = try? JSONSerialization.data(withJSONObject: json),
                                   let str = String(data: data, encoding: .utf8) {
                                    mqttManager.send(jsonString: str)
                                }
                            }
                        ),
                        trackColor: .yellow,
                        knobColor: .yellow,
                        width: rightWidth * 0.45, // narrower
                        height: sliderHeight
                    )
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .edgesIgnoringSafeArea(.all)
        }
    }
    
    private func sendControlUpdate(left: CGSize, right: CGSize, sliderY: CGFloat?, padSize: CGFloat, sliderHeight: CGFloat, changed: ControlType) {
        // Normalize joystick values: -1...1 (center is 0,0)
        let maxRadius = Double((padSize - padSize * 0.13) / 2)
        let leftX = maxRadius == 0 ? 0 : Double(left.width) / maxRadius
        let leftY = maxRadius == 0 ? 0 : Double(left.height) / maxRadius
        let rightX = maxRadius == 0 ? 0 : Double(right.width) / maxRadius
        let rightY = maxRadius == 0 ? 0 : Double(right.height) / maxRadius
        // Normalize slider: 0 (bottom) ... 1 (top)
        let barHeight = Double(sliderHeight * 0.8)
        let knobRadius = Double(sliderHeight * 0.13 * 0.7)
        let margin = Double(sliderHeight * 0.13 - CGFloat(knobRadius)) / 2
        let minCenterY = margin + knobRadius / 2
        let maxCenterY = barHeight - margin - knobRadius / 2
        let sliderNorm: Double = {
            guard let y = sliderY else { return 0 }
            return max(0, min(1, 1 - (Double(y) - minCenterY) / (maxCenterY - minCenterY)))
        }()
        var json: [String: Any] = [:]
        switch changed {
        case .left:
            json["left"] = ["x": leftX, "y": leftY]
        case .right:
            json["right"] = ["x": rightX, "y": rightY]
        case .slider:
            json["slider"] = sliderNorm
        }
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            mqttManager.send(jsonString: str)
        }
    }
}

struct CenterSliderBar: View {
    let height: CGFloat
    let barWidth: CGFloat
    @Binding var knobY: CGFloat?
    var onUpdate: (CGFloat?) -> Void
    
    var body: some View {
        let barHeight = height * 0.8
        let knobRadius = barWidth * 0.7
        let margin = (barWidth - knobRadius) / 2
        let minCenterY = margin + knobRadius / 2
        let maxCenterY = barHeight - margin - knobRadius / 2
        let currentCenterY = knobY ?? maxCenterY
        
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: barWidth, height: barHeight)
                    .shadow(radius: 2)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobRadius, height: knobRadius)
                    .shadow(radius: 3)
                    .position(x: barWidth / 2, y: currentCenterY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let y = min(max(value.location.y, minCenterY), maxCenterY)
                                knobY = y
                                onUpdate(y)
                            }
                    )
                    .accessibilityLabel("Center Slider Knob")
            }
            .frame(width: barWidth, height: barHeight)
            Spacer()
        }
        .frame(width: barWidth, height: height)
    }
}

struct TouchPadView: View {
    let color: Color
    let accessibilityPrefix: String
    @Binding var dragOffset: CGSize
    @Binding var lastValue: CGSize
    var onUpdate: (CGSize, CGSize) -> Void
    let padSize: CGFloat
    var onRelease: (() -> Void)? = nil
    
    var body: some View {
        let knobRadius = padSize * 0.13
        let center = CGPoint(x: padSize / 2, y: padSize / 2)
        let currentPosition = CGPoint(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color.opacity(0.5))
                .shadow(radius: 4)
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: padSize * 0.7, height: padSize * 0.7)
            // Crosshair lines
            Path { path in
                path.move(to: CGPoint(x: currentPosition.x, y: 0))
                path.addLine(to: CGPoint(x: currentPosition.x, y: currentPosition.y))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 3)
            Path { path in
                path.move(to: CGPoint(x: currentPosition.x, y: padSize))
                path.addLine(to: CGPoint(x: currentPosition.x, y: currentPosition.y))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 3)
            Path { path in
                path.move(to: CGPoint(x: 0, y: currentPosition.y))
                path.addLine(to: CGPoint(x: currentPosition.x, y: currentPosition.y))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 3)
            Path { path in
                path.move(to: CGPoint(x: padSize, y: currentPosition.y))
                path.addLine(to: CGPoint(x: currentPosition.x, y: currentPosition.y))
            }
            .stroke(Color.white.opacity(0.7), lineWidth: 3)
            // Joystick knob (always visible)
            Circle()
                .fill(Color.white)
                .frame(width: knobRadius, height: knobRadius)
                .shadow(radius: 3)
                .position(currentPosition)
                .animation(.easeOut(duration: 0.15), value: currentPosition)
                .accessibilityLabel("\(accessibilityPrefix) Touch Indicator")
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let dx = value.location.x - center.x
                    let dy = value.location.y - center.y
                    let maxRadius = (padSize - knobRadius) / 2
                    let distance = sqrt(dx*dx + dy*dy)
                    let clamped: CGSize
                    if distance > maxRadius {
                        let angle = atan2(dy, dx)
                        clamped = CGSize(width: cos(angle) * maxRadius, height: sin(angle) * maxRadius)
                    } else {
                        clamped = CGSize(width: dx, height: dy)
                    }
                    dragOffset = clamped
                    lastValue = clamped
                    onUpdate(clamped, clamped)
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragOffset = .zero
                    }
                    // On release, send (0,0) for this joystick
                    onUpdate(.zero, .zero)
                    onRelease?()
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct VerticalSlider: View {
    @Binding var value: Double // -1...1, 0 is center
    var trackColor: Color = .yellow
    var knobColor: Color = .yellow
    var width: CGFloat = 32 // narrower
    var height: CGFloat = 180
    var margin: CGFloat = 12 // margin from top and bottom

    var body: some View {
        GeometryReader { geo in
            let sliderHeight = geo.size.height
            let knobRadius = width * 0.7
            let minY = margin + knobRadius / 2
            let maxY = sliderHeight - margin - knobRadius / 2
            let y = ((1 - value) / 2) * (maxY - minY) + minY

            ZStack(alignment: .top) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: width, height: sliderHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobRadius, height: knobRadius)
                    .shadow(radius: 2)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .position(x: width / 2, y: y)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newY = min(max(gesture.location.y, minY), maxY)
                                value = 1 - 2 * ((newY - minY) / (maxY - minY))
                            }
                    )
            }
        }
        .frame(width: width, height: height)
    }
}

struct ContentView: View {
    var body: some View {
        ControlPanelView()
    }
}

#Preview {
    ContentView()
}
