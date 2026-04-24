import pytest

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


def test_list_ports_contains_loopback_entry():
    bridge = SerialBridge()
    ports = bridge.list_ports()

    assert any(item["port"] == "loop://" for item in ports)


def test_read_after_close_raises_key_error():
    bridge = SerialBridge()
    handle = bridge.open("loop://", 115200)
    bridge.close(handle)

    with pytest.raises(KeyError):
        bridge.read(handle, timeout=0.1)
