using UnityEngine;
using M2MqttUnity;
using uPLibrary.Networking.M2Mqtt.Messages;
using System;
using System.Collections;

/// <summary>
/// Receives control data from MQTT and applies it to a prefab.
/// </summary>
public class MqttController : M2MqttUnityClient
{
    [Header("Prefab to Instantiate and Control")]
    public GameObject prefabToInstantiate; // Assign this in the Inspector
    public float spawnDistance = 2.0f;     // Distance in front of the camera

    [Header("Movement Settings")]
    public float moveSpeed = 2f;
    public float rotateSpeed = 100f;
    public float scaleMin = 0.05f;
    public float scaleMax = 0.25f;

    [Header("Thrust Settings")]
    public float thrustForce = 5f; // Force applied when thrust is triggered

    [Header("Cloak Settings")]
    public float cloakDuration = 3f; // Duration the prefab stays hidden

    private GameObject controlledPrefab;   // The instance to control
    private string[] topics;
    private Rigidbody prefabRigidbody; // For applying thrust force

    // Target state for smooth movement/rotation/scale
    private Vector3 targetPosition;
    private Quaternion targetRotation;
    private Vector3 targetScale;
    private bool hasTarget = false;

    private Vector2 moveInput = Vector2.zero; // Store latest joystick input for smooth movement
    private Vector2 rotateInput = Vector2.zero; // Store latest right joystick input for smooth rotation
    private Vector2 currentRotateInput = Vector2.zero; // For smoothing rotation input
    private float deadZone = 0.1f; // Dead zone for joystick input

    // Cloak state
    private bool isCloaked = false;
    private Coroutine cloakCoroutine;

    // Thrust state
    private Vector3 startingPosition;
    private Coroutine thrustCoroutine;

    // Movement rotation variables
    private bool isRotatingToFaceMovement = false;
    private Quaternion targetMovementRotation;
    private float rotationThreshold = 0.1f; // How close to target rotation before moving
    
    // Smooth movement variables
    private Vector3 currentVelocity = Vector3.zero;
    private Vector3 targetVelocity = Vector3.zero;
    private float velocitySmoothTime = 0.1f; // Time to smooth velocity changes

    protected override void Start()
    {
        // Set broker and topic here or in the Inspector
        brokerAddress = "broker.emqx.io";
        brokerPort = 1883;
        topics = new string[] { "mycontroller/controls" };

        // Instantiate the prefab in front of the main camera
        if (prefabToInstantiate != null)
        {
            Camera mainCam = Camera.main;
            if (mainCam != null)
            {
                Vector3 spawnPos = mainCam.transform.position + mainCam.transform.forward * spawnDistance;
                controlledPrefab = Instantiate(prefabToInstantiate, spawnPos, Quaternion.identity);
                
                // Add Rigidbody if it doesn't exist for thrust functionality
                prefabRigidbody = controlledPrefab.GetComponent<Rigidbody>();
                if (prefabRigidbody == null)
                {
                    prefabRigidbody = controlledPrefab.AddComponent<Rigidbody>();
                    prefabRigidbody.useGravity = false; // Disable gravity to make it float
                    prefabRigidbody.drag = 3f; // Increased drag for smoother movement
                    prefabRigidbody.angularDrag = 3f; // Increased angular drag to prevent spinning
                }
                else
                {
                    // If Rigidbody already exists, configure it for floating
                    prefabRigidbody.useGravity = false;
                    prefabRigidbody.drag = 3f;
                    prefabRigidbody.angularDrag = 3f;
                }
                
                // Set initial scale to be smaller
                float initialScale = 0.1f;
                controlledPrefab.transform.localScale = Vector3.one * initialScale;
                // Initialize targets
                targetPosition = controlledPrefab.transform.position;
                targetRotation = controlledPrefab.transform.rotation;
                targetScale = Vector3.one * initialScale; // Initialize target scale
                startingPosition = controlledPrefab.transform.position; // Store starting position
                hasTarget = true;
            }
            else
            {
                Debug.LogWarning("Main Camera not found!");
            }
        }
        else
        {
            Debug.LogWarning("Prefab to instantiate is not assigned!");
        }

        base.Start();
    }

    protected override void SubscribeTopics()
    {
        if (client != null && topics != null)
        {
            foreach (var topic in topics)
            {
                client.Subscribe(new string[] { topic }, new byte[] { MqttMsgBase.QOS_LEVEL_AT_MOST_ONCE });
            }
        }
    }

    protected override void UnsubscribeTopics()
    {
        if (client != null && topics != null)
        {
            foreach (var topic in topics)
            {
                client.Unsubscribe(new string[] { topic });
            }
        }
    }

    protected override void DecodeMessage(string topic, byte[] message)
    {
        string msg = System.Text.Encoding.UTF8.GetString(message);
        Debug.Log($"Received on topic '{topic}': {msg}");

        try
        {
            // Try to parse left joystick
            var leftData = JsonUtility.FromJson<LeftData>(msg);
            if (leftData != null && leftData.left != null)
            {
                Vector2 input = new Vector2(leftData.left.x, leftData.left.y);
                if (input.magnitude > 1f) input.Normalize();
                if (input.magnitude < deadZone) input = Vector2.zero;
                moveInput = input;
                if (Mathf.Approximately(input.x, 0f) && Mathf.Approximately(input.y, 0f))
                {
                    moveInput = Vector2.zero;
                }
            }

            // Try to parse right joystick
            var rightData = JsonUtility.FromJson<RightData>(msg);
            if (rightData != null && rightData.right != null)
            {
                Vector2 input = new Vector2(rightData.right.x, rightData.right.y);
                if (input.magnitude > 1f) input.Normalize();
                if (input.magnitude < deadZone) input = Vector2.zero;
                rotateInput = input;
                if (Mathf.Approximately(input.x, 0f) && Mathf.Approximately(input.y, 0f))
                {
                    rotateInput = Vector2.zero;
                }
            }

            // Try to parse slider - simplified approach
            if (msg.Contains("\"slider\""))
            {
                Debug.Log($"Raw slider message: {msg}");
                
                // Try simple string parsing first
                int sliderIndex = msg.IndexOf("\"slider\":");
                if (sliderIndex != -1)
                {
                    int valueStart = sliderIndex + 9; // Length of "slider":
                    int valueEnd = msg.IndexOf(",", valueStart);
                    if (valueEnd == -1) valueEnd = msg.IndexOf("}", valueStart);
                    
                    if (valueEnd != -1)
                    {
                        string sliderValueStr = msg.Substring(valueStart, valueEnd - valueStart).Trim();
                        if (float.TryParse(sliderValueStr, out float sliderValue))
                        {
                            Debug.Log($"Parsed slider value: {sliderValue}");
                            
                            // Map iOS controller value (-1 to +1) to Unity scale
                            // Slider 0 = starting scale (0.1), Slider 1 = 0.25, Slider -1 = 0.05
                            float startingScale = 0.1f; // This is our reference point
                            float scaleUpRange = 0.25f - startingScale; // 0.15f
                            float scaleDownRange = startingScale - 0.05f; // 0.05f
                            
                            float targetScaleValue;
                            if (sliderValue >= 0)
                            {
                                // Positive values: scale up from starting scale
                                targetScaleValue = startingScale + (sliderValue * scaleUpRange);
                            }
                            else
                            {
                                // Negative values: scale down from starting scale
                                targetScaleValue = startingScale + (sliderValue * scaleDownRange);
                            }
                            
                            targetScale = Vector3.one * targetScaleValue;
                            Debug.Log($"Slider: {sliderValue}, Starting Scale: {startingScale}, Target Scale: {targetScale.x}");
                        }
                        else
                        {
                            Debug.LogError($"Failed to parse slider value: {sliderValueStr}");
                        }
                    }
                }
                
                // Also try JsonUtility as backup
                var sliderData = JsonUtility.FromJson<SliderData>(msg);
                if (sliderData != null)
                {
                    Debug.Log($"JsonUtility parsed slider: {sliderData.slider}");
                }
            }

            // Handle thrust command
            if (msg.Contains("\"thrust\":true"))
            {
                ApplyThrust();
            }

            // Handle cloak command
            if (msg.Contains("\"cloak\":true"))
            {
                ActivateCloak();
            }

            // Handle reset command
            if (msg.Contains("\"reset\":true"))
            {
                ResetPrefab();
            }

            hasTarget = true;
        }
        catch (System.Exception ex)
        {
            Debug.LogError("JSON parse error: " + ex);
        }
    }

    private void ApplyThrust()
    {
        if (prefabRigidbody != null && !isCloaked)
        {
            // Apply upward force in Y direction
            prefabRigidbody.AddForce(Vector3.up * thrustForce, ForceMode.Impulse);
            Debug.Log("Thrust applied!");
        }
    }

    private void ActivateCloak()
    {
        if (isCloaked) return; // Already cloaked

        if (cloakCoroutine != null)
        {
            StopCoroutine(cloakCoroutine);
        }
        cloakCoroutine = StartCoroutine(CloakSequence());
    }

    private IEnumerator CloakSequence()
    {
        isCloaked = true;
        
        // Hide the prefab
        if (controlledPrefab != null)
        {
            Renderer[] renderers = controlledPrefab.GetComponentsInChildren<Renderer>();
            foreach (Renderer renderer in renderers)
            {
                renderer.enabled = false;
            }
        }
        
        Debug.Log("Cloak activated - prefab hidden for 3 seconds");
        
        // Wait for cloak duration
        yield return new WaitForSeconds(cloakDuration);
        
        // Show the prefab again
        if (controlledPrefab != null)
        {
            Renderer[] renderers = controlledPrefab.GetComponentsInChildren<Renderer>();
            foreach (Renderer renderer in renderers)
            {
                renderer.enabled = true;
            }
        }
        
        isCloaked = false;
        Debug.Log("Cloak deactivated - prefab visible again");
    }

    protected override void Update()
    {
        base.Update();

        if (controlledPrefab == null || !hasTarget) return;

        // Don't allow movement or rotation while cloaked
        if (isCloaked) return;

        // --- Handle movement with rotation-to-face ---
        if (moveInput.magnitude > deadZone)
        {
            // Calculate the movement direction in world space
            Vector3 moveDirection = new Vector3(moveInput.x, 0, moveInput.y).normalized;
            
            // Calculate the target rotation to face the movement direction
            // Use negative direction so front faces movement direction
            targetMovementRotation = Quaternion.LookRotation(-moveDirection);
            
            // Check if we need to rotate to face the movement direction
            float angleDifference = Quaternion.Angle(controlledPrefab.transform.rotation, targetMovementRotation);
            
            if (angleDifference > rotationThreshold)
            {
                // Still rotating to face movement direction
                isRotatingToFaceMovement = true;
                controlledPrefab.transform.rotation = Quaternion.Slerp(
                    controlledPrefab.transform.rotation, 
                    targetMovementRotation, 
                    0.05f // Reduced rotation speed for smoother turning
                );
                // Gradually reduce velocity while rotating
                targetVelocity = Vector3.zero;
            }
            else
            {
                // Facing the right direction, now move
                isRotatingToFaceMovement = false;
                targetVelocity = moveDirection * moveSpeed;
            }
        }
        else
        {
            // No movement input, gradually stop
            targetVelocity = Vector3.zero;
            isRotatingToFaceMovement = false;
        }

        // Smooth velocity changes
        currentVelocity = Vector3.Lerp(currentVelocity, targetVelocity, Time.deltaTime / velocitySmoothTime);
        
        // Apply velocity to position
        controlledPrefab.transform.position += currentVelocity * Time.deltaTime;

        // --- Handle right joystick rotation (independent of movement) ---
        currentRotateInput = Vector2.Lerp(currentRotateInput, rotateInput, 0.2f);
        float yRotationStep = currentRotateInput.x * rotateSpeed * Time.deltaTime;
        controlledPrefab.transform.Rotate(Vector3.up, yRotationStep, Space.World);

        // Smoothly scale towards target scale
        Vector3 currentScale = controlledPrefab.transform.localScale;
        Vector3 newScale = Vector3.Lerp(currentScale, targetScale, 0.08f);
        controlledPrefab.transform.localScale = newScale;
        
        // Debug scaling
        if (Mathf.Abs(currentScale.x - targetScale.x) > 0.01f)
        {
            Debug.Log($"Scaling: Current={currentScale.x:F3}, Target={targetScale.x:F3}, New={newScale.x:F3}");
        }
    }

    private void ResetPrefab()
    {
        if (controlledPrefab != null && !isCloaked)
        {
            // Reset position to starting position
            controlledPrefab.transform.position = startingPosition;
            
            // Reset rotation to identity (no rotation)
            controlledPrefab.transform.rotation = Quaternion.identity;
            
            // Reset scale to initial scale
            float initialScale = 0.1f;
            controlledPrefab.transform.localScale = Vector3.one * initialScale;
            targetScale = Vector3.one * initialScale;
            
            // Reset rigidbody velocity
            if (prefabRigidbody != null)
            {
                prefabRigidbody.velocity = Vector3.zero;
                prefabRigidbody.angularVelocity = Vector3.zero;
            }
            
            // Reset input values
            moveInput = Vector2.zero;
            rotateInput = Vector2.zero;
            currentRotateInput = Vector2.zero;
            
            Debug.Log("Prefab reset to initial state!");
        }
    }

    [System.Serializable]
    public class ControllerData
    {
        public JoystickData left;
        public JoystickData right;
        public float slider;
    }

    [System.Serializable]
    public class JoystickData
    {
        public float x;
        public float y;
    }

    // Add minimal classes for partial payloads
    [System.Serializable]
    public class LeftData
    {
        public JoystickData left;
    }
    [System.Serializable]
    public class RightData
    {
        public JoystickData right;
    }
    [System.Serializable]
    public class SliderData
    {
        public float slider;
    }
}