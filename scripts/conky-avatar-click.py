#!/usr/bin/env python3
import os, sys, subprocess

GAP_X, GAP_Y = 32, 265
AX, AY, R = 178, 58, 28
W = H = R * 2
ROTATE = os.path.expanduser("~/.local/bin/rotate-wallpaper.sh")

def rotate():
    try:
        subprocess.Popen(["bash", ROTATE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

import tkinter as tk

root = tk.Tk()
root.overrideredirect(True)
root.attributes("-topmost", True)
try: root.attributes("-alpha", 0.01)
except tk.TclError: pass
try: root.wm_attributes("-type", "dock")
except Exception: pass
x, y = GAP_X + AX - R, GAP_Y + AY - R
root.geometry(f"{W}x{H}+{x}+{y}")
root.configure(bg="#010101")
try: root.wm_attributes("-transparentcolor", "#010101")
except Exception: pass

c = tk.Canvas(root, width=W, height=H, bg="#010101", highlightthickness=0, bd=0)
c.pack()
c.create_oval(2, 2, W-2, H-2, outline="", fill="#010101")
root.bind("<Button-1>", lambda e: rotate())
c.bind("<Button-1>", lambda e: rotate())
root.bind("<Enter>", lambda e: root.config(cursor="hand2"))
root.mainloop()
