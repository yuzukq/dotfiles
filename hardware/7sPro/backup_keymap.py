#!/usr/bin/env python3
"""VIAの生HID経由で現在のダイナミックキーマップ全体を読み出し、JSONファイルにバックアップするスクリプト
EEPROMの復元はrestore_keymap.pyで可能
"""
import json
import sys

import hid

VENDOR_ID = 0x04D8
PRODUCT_ID = 0xEB5F
USAGE_PAGE = 0xFF60
USAGE = 0x61

GET_KEYCODE = 0x04

LAYER_COUNT = 4
MATRIX_ROWS = 10
MATRIX_COLS = 8


def find_device():
    for d in hid.enumerate(VENDOR_ID, PRODUCT_ID):
        if d.get("usage_page") == USAGE_PAGE and d.get("usage") == USAGE:
            return d
    raise RuntimeError("7sKB raw HID (VIA) interface not found. Is it plugged in?")


def get_keycode(dev, layer, row, col):
    report = bytes([0x00, GET_KEYCODE, layer, row, col])
    report = report + bytes(33 - len(report))
    dev.write(report)
    resp = dev.read(32, timeout=1000)
    return (resp[4] << 8) | resp[5]


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "keymap_backup.json"

    info = find_device()
    print(f"Opening: {info['product_string']} (path={info['path']})")
    dev = hid.Device(path=info["path"])

    backup = []
    try:
        for layer in range(LAYER_COUNT):
            layer_data = []
            for row in range(MATRIX_ROWS):
                row_data = []
                for col in range(MATRIX_COLS):
                    kc = get_keycode(dev, layer, row, col)
                    row_data.append(kc)
                layer_data.append(row_data)
            backup.append(layer_data)
            print(f"  layer {layer} done")
    finally:
        dev.close()

    with open(out_path, "w") as f:
        json.dump({"layer_count": LAYER_COUNT, "rows": MATRIX_ROWS, "cols": MATRIX_COLS, "keymap": backup}, f, indent=2)
    print(f"Saved to {out_path}")


if __name__ == "__main__":
    main()
