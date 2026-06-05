#!/usr/bin/env python3
"""
Simple touch coordinate monitor via ADB.
Shows where you tap/swipe on the phone screen in real-time.

Usage: python3 touch_monitor.py
Press Ctrl+C to stop.
"""

import subprocess
import re

def main():
    print("📱 Touch Monitor - Tap or swipe on your phone screen")
    print("   Coordinates will appear below. Press Ctrl+C to stop.\n")

    x, y = 0, 0
    touching = False

    proc = subprocess.Popen(
        ["adb", "shell", "getevent", "-lt"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    try:
        for line in proc.stdout:
            line = line.strip()

            if "ABS_MT_POSITION_X" in line:
                match = re.search(r"ABS_MT_POSITION_X\s+([0-9a-fA-F]+)", line)
                if match:
                    x = int(match.group(1), 16)

            elif "ABS_MT_POSITION_Y" in line:
                match = re.search(r"ABS_MT_POSITION_Y\s+([0-9a-fA-F]+)", line)
                if match:
                    y = int(match.group(1), 16)

            elif "BTN_TOUCH" in line and "DOWN" in line:
                touching = True
                print(f"👇 TOUCH DOWN  x={x}  y={y}")

            elif "BTN_TOUCH" in line and "UP" in line:
                print(f"👆 TOUCH UP    x={x}  y={y}")
                if touching:
                    print(f"   ─── Swipe: ended at ({x}, {y})")
                touching = False
                print()

            # Also print move events periodically (every position update when Y changes)
            elif "SYN_REPORT" in line and touching:
                print(f"   ✋ MOVE      x={x}  y={y}", end="\r")

    except KeyboardInterrupt:
        print("\n\n🛑 Stopped.")
    finally:
        proc.kill()

if __name__ == "__main__":
    main()
