#!/usr/bin/env python3
"""VIAの生HID(id_get_keyboard_value / id_switch_matrix_state)経由で
生のマトリクススキャン状態を継続的にポーリングしハード的な導通を確認する診断ツール

* VIA_INSECURE=yes を焼いたファームウェアが必要
"""
import sys
import time

import hid

VENDOR_ID = 0x04D8
PRODUCT_ID = 0xEB5F
USAGE_PAGE = 0xFF60
USAGE = 0x61

GET_KEYBOARD_VALUE = 0x02
SWITCH_MATRIX_STATE = 0x03

MATRIX_ROWS = 10


def find_device():
    for d in hid.enumerate(VENDOR_ID, PRODUCT_ID):
        if d.get("usage_page") == USAGE_PAGE and d.get("usage") == USAGE:
            return d
    raise RuntimeError("7sKB raw HID (VIA) interface not found. Is it plugged in?")


def read_matrix(dev):
    report = bytes([0x00, GET_KEYBOARD_VALUE, SWITCH_MATRIX_STATE, 0])
    report = report + bytes(33 - len(report))
    dev.write(report)
    resp = dev.read(32, timeout=1000)
    # response row bytes start at index 4 (see quantum/via.c: command_data[2..])
    return resp[4 : 4 + MATRIX_ROWS]


def main():
    duration = float(sys.argv[1]) if len(sys.argv) > 1 else 8.0

    info = find_device()
    print(f"Opening: {info['product_string']} (path={info['path']})")
    dev = hid.Device(path=info["path"])

    print(f"Polling for {duration}s. Press/hold the keys you want to test now...")
    seen = set()
    start = time.time()
    try:
        while time.time() - start < duration:
            rows = read_matrix(dev)
            for row, value in enumerate(rows):
                if value == 0:
                    continue
                for col in range(8):
                    if value & (1 << col):
                        key = (row, col)
                        if key not in seen:
                            seen.add(key)
                            print(f"  DETECTED: row={row} col={col}")
            time.sleep(0.02)
    finally:
        dev.close()

    if not seen:
        print("No key presses detected at the matrix level during this window.")
    else:
        print(f"Total distinct (row,col) detected: {sorted(seen)}")


if __name__ == "__main__":
    main()
