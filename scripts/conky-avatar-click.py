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

def is_fullscreen():
    try:
        wid = subprocess.check_output(["xdotool", "getactivewindow"], text=True, timeout=1).strip()
        if not wid or wid == "0":
            aw = subprocess.check_output(["xprop", "-root", "_NET_ACTIVE_WINDOW"], text=True, timeout=1)
            for tok in aw.split():
                if tok.startswith("0x") and tok != "0x0":
                    wid = tok.rstrip(",")
                    break
        if not wid or wid == "0":
            return False
        state = subprocess.check_output(["xprop", "-id", wid, "_NET_WM_STATE"], text=True, timeout=1)
        return "_NET_WM_STATE_FULLSCREEN" in state
    except Exception:
        try:
            state = subprocess.check_output(["xprop", "-root", "_NET_ACTIVE_WINDOW"], text=True, timeout=1)
            return "_NET_WM_STATE_FULLSCREEN" in state
        except Exception:
            return False

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

hidden = False
def check_fs():
    global hidden
    fs = is_fullscreen()
    if fs and not hidden:
        root.withdraw()
        hidden = True
    elif not fs and hidden:
        root.deiconify()
        root.attributes("-topmost", True)
        hidden = False
    root.after(500, check_fs)

root.after(500, check_fs)
root.mainloop()
