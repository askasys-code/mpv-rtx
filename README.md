# 🎛️ MPV-RTX (NVIDIA Dark Glass Edition)

<p align="center">
  <a href="https://mpv.io"><img src="https://img.shields.io/badge/MPV-gpu--next-00E676?style=for-the-badge&logo=mpv&logoColor=white" alt="Engine"></a>
  <a href="https://nvidia.com"><img src="https://img.shields.io/badge/RTX_Video-VSR_%7C_True_HDR-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="AI Upscaling"></a>
  <a href="#-the-nvidia-dark-glass-aesthetic"><img src="https://img.shields.io/badge/Design-NVIDIA_Dark_Glass-0A0A0A?style=for-the-badge&logo=materialdesign&logoColor=00E676" alt="Aesthetics"></a>
</p>

A videophile-grade mpv setup for Direct3D 11 and NVIDIA RTX, built on `vo=gpu-next`: zero-copy hardware decoding, judder-free pacing, RTX AI upscaling, a manual film grain controller, diagnostic HUDs and a glassmorphism UI, all drawn as vector ASS overlays.

<img width="3840" height="2160" alt="{05C12C6A-CC41-4814-91DD-260965ACBEE2}" src="https://github.com/user-attachments/assets/6f099302-a57b-4195-869b-371b57f223be" />

## 📑 Contents
[Aesthetic](#-the-nvidia-dark-glass-aesthetic) · [Engine](#-core-engine) · [Upscaling](#-upscaling--hdr) · [Film Grain](#-film-grain-controller) · [HUDs](#-diagnostic-huds) · [OSC](#-bottom-bar-osc) · [Clip Maker](#-clip-maker-w) · [Shortcuts](#️-shortcuts) · [Install](#-installation) · [Structure](#-file-structure)

## 💎 The NVIDIA Dark Glass Aesthetic

* **Obsidian glass cards** (`#0A0A0A`, ~80% opacity): readable over any video.
* **NVIDIA green** (`#00E676`) accents and **RivaTuner cyan** (`#00E5FF`) readouts.
* **OLED pure black** letterboxing (`#000000`).
* **Anti-collision docking**: toasts move out of the way of active HUDs.
* **DPI-aware scaling** from 1080p to 4K and ultra-wide.

## ⚡ Core Engine

* **Direct3D 11 flip presentation** with automatic color space detection and Windows HDR passthrough.
* **Zero-copy decoding** (`hwdec=d3d11va`): AV1 10-bit, HEVC, H.264, VP9.
* **Judder-free pacing**: `display-resample` + `oversample` + interpolation, 60 Hz to 240 Hz+.
* **Clean scaling**: Lanczos with clamp and anti-ringing; dedicated fast `[IMAGE]` profile for photos.

## 🚀 Upscaling & HDR

| Key | Engine | Notes |
| :---: | :--- | :--- |
| **`1`** | NVIDIA RTX VSR | Tensor-core AI upscaling up to 4x (`Alt+1` re-scales after a resize) |
| **`2`** | NVIDIA NIS | Adaptive sharpening and upscaling shader |
| **`3`** | AMD FSR 1.0 | EASU + RCAS |
| **`4`** | Qualcomm SGSR | Single-pass edge-aware shader |
| **`5`** | AMD CAS | Contrast-adaptive sharpening |
| **`h`** | RTX True HDR | SDR → HDR10 (PQ), with native-HDR protection |
| **`9`** | Base scaler | Toggles `lanczos` / `nearest` |
| **`0`** | Master reset | Clears shaders, VSR/HDR, grain, audio filters and geometry |

## 🎞️ Film Grain Controller

Fully manual: the script never inspects the stream or guesses what a file contains.

| Key | Action |
| :---: | :--- |
| **`6`** / **`G`** | Cycle **GPU synthetic grain** on any codec: `Off` → `Light` (+128) → `Medium` (+256) → `Heavy` (+512) |
| **`Ctrl+6`** | Toggle **native AV1 FGS** on/off (`format=film-grain=no`) |
| **`Alt+6`** / **`Alt+G`** | Open the grain diagnostics HUD |

* GPU grain uses mpv's deband carrier with `threshold=1`: no detail smoothing, no gray lift (OLED safe).
* Your own deband settings are saved before the first preset and restored on `Off` and on file change.
* The HUD warns about possible **grain stacking** when a GPU preset runs on an AV1 stream whose native FGS is not stripped.

## 📊 Diagnostic HUDs

* **NVIDIA Monitor (`g`)**: clocks, GPU/NVDEC load, temperature, fan, power, VRAM, refresh rate, dropped frames, render latency, VRR detection.
* **Video Monitor (`i`)**: container, cache, codec, decoder, aspect ratio, effective upscaled resolution, bit depth, gamut and gamma. The *Film Grain* field shows `N/A` by default and `Stripped / OFF` only when the AV1 strip filter is active.
* **Audio Monitor (`a`)**: 7.1 speaker matrix, sample rate and bit depth, A/V drift, headphone DSP presets (`A`), zero-clipping bass boost (`b`) and channel soloing (`B`, `Ctrl+1-5,0`).
* **Keybindings Cheatsheet (`F1` / `?`)**: parses `input.conf` live on every open, supports inline `# comments` as labels. `ESC` closes it without quitting mpv.
* **Master view (`TAB`)**: opens or closes the Video and NVIDIA monitors together.

## 🎮 Bottom Bar (OSC)

* Standalone controller with a decoupled 60 FPS render loop and window dragging from anywhere on the video.
* Right-docked badges: resolution scaling, `HW`/`SW`, scaler, dynamic range (`SDR`, `HDR10 (PQ)`, `HLG`, `RTX TRUE HDR`) and grain: `[GPU GRAIN LIGHT/MEDIUM/HEAVY]` or `[AV1 FGS OFF]`, shown only when active.
* Clickable audio and subtitle track menus, volume slider with wheel support, chapter ticks with hover tooltips.

## 🎬 Clip Maker (`W`)

* NVENC encoding (`avc`, `hevc`, `av1`) with CPU fallbacks (`x264`, `x265`, `vp9`, `gif`).
* Stability fixes: zero B-frames on NVENC MP4, automatic `yuv420p` for 10-bit/HDR sources, even-dimension clamping.
* Interactive crop selector with in-player A-B preview; auto-detects a portable `mpv.exe`.

## ⌨️ Shortcuts

| Key | Action |
| :---: | :--- |
| `1`–`5`, `h`, `9`, `0` | Upscalers, True HDR, base scaler, master reset |
| `6` / `G` · `Ctrl+6` · `Alt+6` | GPU grain presets · native AV1 FGS · grain HUD |
| `g` · `i` · `a` · `TAB` | NVIDIA / Video / Audio monitors · both video monitors |
| `A` · `b` · `B` | Headphone DSP · bass boost · channel solo |
| `W` | Clip Maker |
| `F1` / `?` | Keybindings cheatsheet |

## 📦 Installation

**Requirements:** Windows with D3D11, an NVIDIA RTX GPU (for VSR / True HDR) and a recent mpv build with `gpu-next`.

1. Download or clone this repository.
2. Copy its contents into your mpv `portable_config` folder (or `%APPDATA%\mpv`).
3. Launch mpv. Press `F1` to see every shortcut.

## 📂 File Structure

```
mpv/
├── mpv.conf · input.conf · fonts.conf
├── configs/          # file-extension lists
├── scalers/          # NVScaler, FSR, SGSR, CAS-scaled (.glsl)
├── scripts/          # OSC, monitors, film-grain, clip-maker, keybinds-hud, auto-hdr, auto-vsr, notify
└── script-modules/   # dark-glass (theme), glass-card (rendering), suite-util (shared helpers)
```

## 📜 Credits & License

* **Core player:** [mpv](https://mpv.io), copyright mpv developers.
* **Shaders:** NVIDIA NIS (NVIDIA), FidelityFX FSR & CAS (AMD), Snapdragon GSR (Qualcomm); GLSL ports by [agyild](https://github.com/agyild/mpv-shaders).
* **Suite:** built and maintained by [askasys-code](https://github.com/askasys-code).
* **License:** [MIT](LICENSE).


