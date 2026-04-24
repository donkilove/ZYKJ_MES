from plugins.serial_assistant.app.serial_bridge import SerialBridge


def test_loopback_round_trip():
    bridge = SerialBridge()
    handle = bridge.open("loop://", 115200)
    try:
        bridge.send(handle, "ping")
        payload = bridge.read(handle, timeout=1.0)
        assert payload == "ping"
    finally:
        bridge.close(handle)
