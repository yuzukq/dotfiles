#!/usr/bin/env python3
"""OSを認識する5つのカスタムキーコードを、生HID（raw HID）経由で7sKBのVIA動的キーマップに書き込むスクリプト
OS_HOME/OS_END/OS_AUTO/OS_MAC/OS_WINを定義したカスタムファームウェア（keymaps/via）
をフラッシュした後、これを1回実行する。

変更されるのはこれら5つのキー位置のみで、現在のキーマップ（Remapで編集した内容など）のその他の部分は一切変更しない。
"""
import hid

VENDOR_ID = 0x04D8
PRODUCT_ID = 0xEB5F
USAGE_PAGE = 0xFF60
USAGE = 0x61

SET_KEYCODE = 0x05

# (layer, row, col, keycode, label)
TARGETS = [
    (1, 1, 3, 0x7E41, "OS_HOME (was *Win/Cmd Left)"),
    (1, 1, 4, 0x7E42, "OS_END (was *Win/Cmd Right)"),
    (3, 5, 5, 0x7E43, "OS_AUTO"),
    (3, 5, 6, 0x7E44, "OS_MAC"),
    (3, 5, 7, 0x7E45, "OS_WIN"),
]


def find_device():
    for d in hid.enumerate(VENDOR_ID, PRODUCT_ID):
        if d.get("usage_page") == USAGE_PAGE and d.get("usage") == USAGE:
            return d
    raise RuntimeError("7sKB raw HID (VIA) interface not found. Is it plugged in?")


def set_keycode(dev, layer, row, col, keycode):
    report = bytes([0x00, SET_KEYCODE, layer, row, col, (keycode >> 8) & 0xFF, keycode & 0xFF])
    report = report + bytes(33 - len(report))  # pad to 32-byte report + leading 0x00
    dev.write(report)
    dev.read(32, timeout=1000)


def main():
    info = find_device()
    print(f"Opening: {info['product_string']} (path={info['path']})")
    dev = hid.Device(path=info["path"])
    try:
        for layer, row, col, keycode, label in TARGETS:
            print(f"  layer={layer} row={row} col={col} -> 0x{keycode:04X}  ({label})")
            set_keycode(dev, layer, row, col, keycode)
        print("Done. Reconnect Remap (or reload the keymap tab) to see the change reflected.")
    finally:
        dev.close()


if __name__ == "__main__":
    main()
