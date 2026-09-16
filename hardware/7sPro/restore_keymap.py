#!/usr/bin/env python3
"""backup_keymap.py で保存したJSONバックアップを、VIAの生HID経由で7sKBのダイナミックキーマップへ書き戻すスクリプト
"""
import json
import sys
import time

import hid

VENDOR_ID = 0x04D8
PRODUCT_ID = 0xEB5F
USAGE_PAGE = 0xFF60
USAGE = 0x61

SET_KEYCODE = 0x05


def find_device():
    for d in hid.enumerate(VENDOR_ID, PRODUCT_ID):
        if d.get("usage_page") == USAGE_PAGE and d.get("usage") == USAGE:
            return d
    raise RuntimeError("7sKB raw HID (VIA) interface not found. Is it plugged in?")


def set_keycode(dev, layer, row, col, keycode):
    report = bytes([0x00, SET_KEYCODE, layer, row, col, (keycode >> 8) & 0xFF, keycode & 0xFF])
    report = report + bytes(33 - len(report))
    dev.write(report)
    dev.read(32, timeout=1000)


def main():
    in_path = sys.argv[1] if len(sys.argv) > 1 else "keymap_backup.json"

    with open(in_path) as f:
        backup = json.load(f)

    info = find_device()
    print(f"Opening: {info['product_string']} (path={info['path']})")
    dev = hid.Device(path=info["path"])

    km = backup["keymap"]
    try:
        for layer in range(backup["layer_count"]):
            for row in range(backup["rows"]):
                for col in range(backup["cols"]):
                    kc = km[layer][row][col]
                    if kc == 0:
                        continue  # KC_NO is the reset default, no need to write it
                    set_keycode(dev, layer, row, col, kc)
            print(f"  layer {layer} restored")
    finally:
        dev.close()
    print("Done. Reconnect Remap (or reload the keymap tab) to see the change reflected.")


if __name__ == "__main__":
    main()
