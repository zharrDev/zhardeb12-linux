#!/usr/bin/env python3
"""Transisi wallpaper smooth via overlay fullscreen yang fade-in.

Alur: tampilkan gambar BARU dalam window fullscreen transparan (alpha 0),
lalu naikkan alpha 0 -> 1 selama DURATION detik. Setelah overlay opaque,
set wallpaper xfce4-desktop di belakangnya (tak terlihat), lalu tutup.
Hasil visual = crossfade mulus lama -> baru.

Ringan: 1 gambar di-resize sekali (PIL), ramp alpha ditangani compositor
(picom) — tanpa blend per-frame, tanpa screenshot, tanpa daemon.
Hidup hanya ~0.5 detik saat switch. Tanpa picom/compositor: fallback instan.

Pakai: wallpaper-fade.py GAMBAR_BARU [DURASI_DETIK]
Exit 0 = sukses; exit != 0 = panggil instant fallback (tanpa fade).
"""
import os
import signal
import subprocess
import sys
import tempfile
import time

PIDFILE = "/tmp/zhardeb-wallpaper-fade.pid"


def kill_previous():
    try:
        with open(PIDFILE) as f:
            old = int(f.read().strip())
        if old != os.getpid():
            os.kill(old, signal.SIGKILL)
    except Exception:
        pass
    try:
        with open(PIDFILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass


def cleanup(tmpfiles):
    for p in [PIDFILE] + list(tmpfiles):
        try:
            if p and os.path.isfile(p):
                os.remove(p)
        except Exception:
            pass


def set_wallpaper(path):
    """Set wallpaper xfce4-desktop (dipanggil saat overlay sudah opaque)."""
    try:
        out = subprocess.run(
            ["xfconf-query", "-c", "xfce4-desktop", "-l"],
            capture_output=True, text=True, timeout=10,
        )
        for line in out.stdout.splitlines():
            key = line.strip()
            if "last-image" in key:
                subprocess.run(
                    ["xfconf-query", "-c", "xfce4-desktop",
                     "-p", key, "-s", path],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL, timeout=10,
                )
    except Exception:
        pass


def main():
    tmpfiles: list = []
    try:
        return _run(tmpfiles)
    finally:
        cleanup(tmpfiles)


def _run(tmpfiles):
    if len(sys.argv) < 2:
        print("pakai: wallpaper-fade.py GAMBAR_BARU [DURASI_DETIK]",
              file=sys.stderr)
        return 1
    new_path = sys.argv[1]
    try:
        duration = float(sys.argv[2]) if len(sys.argv) > 2 else 0.4
    except ValueError:
        duration = 0.4
    if not os.path.isfile(new_path) or duration <= 0:
        return 1
    if not os.environ.get("DISPLAY"):
        return 1

    kill_previous()
    try:
        from PIL import Image
        import tkinter as tk
    except Exception as e:
        print(f"fade skip (tk/PIL tidak ada): {e}", file=sys.stderr)
        return 1

    try:
        root = tk.Tk()
    except Exception as e:
        print(f"fade skip (tk window gagal): {e}", file=sys.stderr)
        return 1

    try:
        sw, sh = root.winfo_screenwidth(), root.winfo_screenheight()
        if sw < 100 or sh < 100:
            raise ValueError("ukuran layar aneh")
        # siapkan gambar seukuran layar sekali saja (tanpa blend per-frame).
        # - skip resize bila sudah pas (LANDSCAPE selalu = resolusi layar)
        # - simpan PPM (raw dump, encode+load jauh lebih cepat dari PNG)
        img = Image.open(new_path).convert("RGB")
        if img.size != (sw, sh):
            img = img.resize((sw, sh), Image.LANCZOS)
        fd, tmppng = tempfile.mkstemp(prefix="zhardeb-fade-", suffix=".ppm")
        os.close(fd)
        tmpfiles.append(tmppng)
        img.save(tmppng, "PPM")

        root.overrideredirect(True)
        root.geometry(f"{sw}x{sh}+0+0")
        root.attributes("-topmost", True)
        root.configure(bg="black", cursor="none")
        photo = tk.PhotoImage(file=tmppng)
        label = tk.Label(root, image=photo, borderwidth=0,
                         highlightthickness=0)
        label.pack(fill="both", expand=True)
        # mulai transparan penuh: layar lama masih terlihat, tanpa flash
        try:
            root.attributes("-alpha", 0.0)
        except Exception:
            pass
        root.update_idletasks()
        root.update()

        # ramp alpha 0 -> 1 (compositor yang menganimasikan: murah)
        steps = max(int(duration / 0.025), 2)
        for i in range(1, steps + 1):
            try:
                root.attributes("-alpha", i / steps)
            except Exception:
                break
            root.update()
            time.sleep(duration / steps)

        # overlay sudah opaque -> ganti wallpaper di belakangnya (tak terlihat)
        set_wallpaper(new_path)
        root.update()
        time.sleep(0.03)
    except Exception as e:
        print(f"fade gagal di tengah jalan: {e}", file=sys.stderr)
        try:
            root.destroy()
        except Exception:
            pass
        return 1
    try:
        root.destroy()
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
