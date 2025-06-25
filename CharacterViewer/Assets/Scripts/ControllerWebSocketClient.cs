using UnityEngine;
using NativeWebSocket;

// Define the data structure for JSON parsing
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

public class ControllerWebSocketClient : MonoBehaviour
{
    WebSocket websocket;

    [Header("Prefab to Control")]
    public GameObject controlledPrefab;

    [Header("Movement Settings")]
    public float moveSpeed = 2f;
    public float rotateSpeed = 100f;
    public float scaleMin = 0.5f;
    public float scaleMax = 2.0f;

    private GameObject instance;
    private Vector2 moveInput = Vector2.zero;
    private Vector2 rotateInput = Vector2.zero;
    private float scaleInput = 1f;

    async void Start()
    {
        // Instantiate the prefab at the origin
        if (controlledPrefab != null)
        {
            instance = Instantiate(controlledPrefab, Vector3.zero, Quaternion.identity);
        }
        else
        {
            Debug.LogError("No prefab assigned to ControllerWebSocketClient!");
        }

        // Replace with your PC's IP address
        websocket = new WebSocket("ws://192.168.1.221:8080");

        websocket.OnOpen += () =>
        {
            Debug.Log("WebSocket Connection open!");
        };

        websocket.OnError += (e) =>
        {
            Debug.Log("WebSocket Error! " + e);
        };

        websocket.OnClose += (e) =>
        {
            Debug.Log("WebSocket Connection closed!");
        };

        websocket.OnMessage += (bytes) =>
        {
            var message = System.Text.Encoding.UTF8.GetString(bytes);
            // Debug.Log("Received: " + message);

            try
            {
                var data = JsonUtility.FromJson<ControllerData>(message);
                
                moveInput = new Vector2(data.left.x, data.left.y);
                rotateInput = new Vector2(data.right.x, data.right.y);
                scaleInput = Mathf.Lerp(scaleMin, scaleMax, data.slider);
            }
            catch (System.Exception ex)
            {
                Debug.LogError("JSON parse error: " + ex);
            }
        };

        await websocket.Connect();
    }

    void Update()
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        websocket?.DispatchMessageQueue();
#endif

        if (instance == null) return;

        // Move
        Vector3 move = new Vector3(moveInput.x, 0, moveInput.y) * moveSpeed * Time.deltaTime;
        instance.transform.position += move;

        // Rotate (Y axis for horizontal, X axis for vertical)
        float yRotation = rotateInput.x * rotateSpeed * Time.deltaTime;
        float xRotation = -rotateInput.y * rotateSpeed * Time.deltaTime;
        instance.transform.Rotate(Vector3.up, yRotation, Space.World);
        instance.transform.Rotate(Vector3.right, xRotation, Space.World);

        // Scale
        instance.transform.localScale = Vector3.one * scaleInput;
    }

    private async void OnApplicationQuit()
    {
        if (websocket != null)
        {
            await websocket.Close();
        }
    }
}