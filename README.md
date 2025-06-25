# PocketPilot
A cross-platform controller system where an iOS app (SwiftUI) acts as a controller for a Unity application, communicating via MQTT. The system provides smooth character movement, rotation, scaling, and special actions with a modern, ergonomic UI.

## Features

### iOS Controller App (SwiftUI)
- **Dual Joystick Control**: 
  - Left joystick (blue) for movement
  - Right joystick (red) for rotation
- **Vertical Slider**: Controls character scaling (0.05x to 0.25x)
- **Action Buttons**:
  - 🟢 Green: Thrust (upward boost)
  - 🟣 Purple: Cloak (3-second invisibility)
  - 🟠 Orange: Reset (return to spawn state)
- **Modern UI**: Responsive design with smooth animations
- **Dark Theme Support**: Optimized colors for both light and dark modes

### Unity Application
- **Smooth Character Movement**: Velocity-based movement with rotation-to-face
- **Physics Integration**: Rigidbody-based thrust and movement
- **Scaling System**: Dynamic character scaling with smooth interpolation
- **Special Actions**:
  - Thrust: Upward force application
  - Cloak: Temporary invisibility with movement/rotation lock
  - Reset: Return to original spawn state
- **MQTT Communication**: Real-time control data reception

## Quick Start

### Prerequisites
- **iOS Development**: Xcode 14+ with iOS 16+ target
- **Unity**: Unity 2022.3 LTS or newer
- **MQTT Broker**: Public broker (broker.emqx.io) or local setup

### iOS App Setup
1. **Open the project** in Xcode
2. **Install dependencies** (CocoaMQTT via Swift Package Manager)
3. **Build and run** on iOS device or simulator
4. **Grant permissions** if prompted

### Unity App Setup
1. **Open the Unity project**
2. **Assign prefab** in MqttController component
3. **Configure settings** in the Inspector:
   - Movement speed
   - Rotation speed
   - Scale range
   - Thrust force
   - Cloak duration
4. **Build and run** the Unity application

## Usage

### Basic Controls
1. **Movement**: Use left joystick to move character
   - Character automatically rotates to face movement direction
   - Smooth acceleration/deceleration
2. **Rotation**: Use right joystick for independent rotation
3. **Scaling**: Use vertical slider to resize character
   - Middle position = default scale (0.1x)
   - Top = maximum scale (0.25x)
   - Bottom = minimum scale (0.05x)

### Special Actions
- **Thrust** (Green Button): Applies upward force to character
- **Cloak** (Purple Button): Makes character invisible for 3 seconds
  - Disables movement and rotation during cloak
  - Automatically becomes visible again
- **Reset** (Orange Button): Returns character to spawn state
  - Resets position, rotation, scale
  - Stops all movement
  - Resets iOS slider to center

## Technical Details

### MQTT Communication
- **Broker**: broker.emqx.io:1883
- **Topic**: mycontroller/controls
- **Message Format**: JSON
- **Message Types**:
  ```json
  // Movement
  {"left": {"x": 0.5, "y": -0.3}}
  
  // Rotation
  {"right": {"x": 0.2, "y": 0.0}}
  
  // Scaling
  {"slider": 0.5}
  
  // Actions
  {"thrust": true}
  {"cloak": true}
  {"reset": true}
  ```

### Unity Scripts
- **MqttController.cs**: Main controller script
  - Handles MQTT message reception
  - Manages character movement, rotation, scaling
  - Implements special actions (thrust, cloak, reset)
  - Smooth movement with rotation-to-face behavior

### iOS Components
- **ContentView.swift**: Main UI layout
- **TouchPadView**: Custom joystick implementation
- **VerticalSlider**: Custom slider with centered knob
- **MQTTManager**: MQTT communication handler

## Platform Support

- **iOS**: 16.0+ (SwiftUI)
- **Unity**: 2022.3 LTS+
- **MQTT**: Any MQTT 3.1.1 compatible broker