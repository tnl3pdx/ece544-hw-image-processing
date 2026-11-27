"""
uart_test.py - ECE 544 UART protocol test for uart_app

Sends framed COMMAND and DATA packets to the Nexys A7 over COM5 and checks
the RESPONSE / DATA frames that come back.

Frame format (both directions):
    SYNC(0xA5) | TYPE | LEN_LO | LEN_HI | PAYLOAD | CHECKSUM
    CHECKSUM = XOR of TYPE, LEN_LO, LEN_HI and every PAYLOAD byte

Run from the sw\\tools folder:
    python uart_test.py
"""

import time
import serial

PORT = "COM5"       # change if Device Manager shows a different COM number
BAUD = 115200

SYNC = 0xA5
CMD, DATA, RESP = 0x01, 0x02, 0x03


def build_frame(ftype, payload):
    """Encode one frame with a correct checksum."""
    n = len(payload)
    chk = ftype ^ (n & 0xFF) ^ (n >> 8)
    for b in payload:
        chk ^= b
    return bytes([SYNC, ftype, n & 0xFF, n >> 8]) + bytes(payload) + bytes([chk])


def read_frame(ser, timeout=2.0):
    """
    Return (type, payload) for the next valid frame, or None if no valid
    frame arrives before the timeout. Bytes before SYNC (for example the
    boot banner text) are skipped.
    """
    end = time.time() + timeout
    while time.time() < end:
        b = ser.read(1)
        if b and b[0] == SYNC:
            break
    else:
        return None

    hdr = ser.read(3)
    if len(hdr) < 3:
        return None
    ftype, len_lo, len_hi = hdr[0], hdr[1], hdr[2]
    n = len_lo | (len_hi << 8)

    rest = ser.read(n + 1)
    if len(rest) < n + 1:
        return None
    payload, chk = rest[:n], rest[n]

    calc = ftype ^ len_lo ^ len_hi
    for b in payload:
        calc ^= b
    if calc != chk:
        return None
    return ftype, payload


def expect_response(ser, name, cmd_payload, expected):
    """Send one COMMAND frame and check the RESPONSE payload."""
    ser.reset_input_buffer()
    ser.write(build_frame(CMD, cmd_payload))
    resp = read_frame(ser)
    ok = resp is not None and resp[0] == RESP and resp[1] == bytes(expected)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}: got {resp}")
    return ok


def data_test(ser):
    """Send a 4-byte DATA chunk and check it comes back unchanged."""
    data = bytes([0xDE, 0xAD, 0xBE, 0xEF])
    ser.reset_input_buffer()
    ser.write(build_frame(DATA, data))
    resp = read_frame(ser)
    ok = resp is not None and resp[0] == DATA and resp[1] == data
    print(f"[{'PASS' if ok else 'FAIL'}] data passthrough: got {resp}")
    return ok


def bad_checksum_test(ser):
    """A frame with a wrong checksum must be ignored: no reply."""
    ser.reset_input_buffer()
    ser.write(bytes([0xA5, 0x01, 0x01, 0x00, 0x01, 0x00]))  # checksum should be 0x01
    resp = read_frame(ser, timeout=1.0)
    ok = resp is None
    print(f"[{'PASS' if ok else 'FAIL'}] bad checksum ignored: got {resp}")
    return ok


def main():
    with serial.Serial(PORT, BAUD, timeout=0.2) as ser:
        time.sleep(0.5)
        results = [
            expect_response(ser, "ping",                  [0x01],                   [0x01, 0x00]),
            expect_response(ser, "set threshold 0x80",    [0x10, 0x80],             [0x10, 0x00]),
            expect_response(ser, "set RGB 10,20,30",      [0x11, 0x10, 0x20, 0x30], [0x11, 0x00]),
            expect_response(ser, "set algorithm 1",       [0x12, 0x01],             [0x12, 0x00]),
            expect_response(ser, "algorithm 9 (bad)",     [0x12, 0x09],             [0x12, 0x03]),
            expect_response(ser, "ping with extra byte",  [0x01, 0x00],             [0x01, 0x01]),
            expect_response(ser, "unknown opcode 0x7F",   [0x7F],                   [0x7F, 0x02]),
            data_test(ser),
            bad_checksum_test(ser),
        ]
    print(f"\n{sum(results)}/{len(results)} tests passed")


if __name__ == "__main__":
    main()