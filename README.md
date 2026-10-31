# 🎛️ MPV-RTX (NVIDIA Dark Glass Edition)

<p align="center">
  <a href="https://mpv.io"><img src="https://img.shields.io/badge/MPV-gpu--next-00E676?style=for-the-badge&logo=mpv&logoColor=white" alt="Engine"></a>
  <a href="https://nvidia.com"><img src="https://img.shields.io/badge/RTX_Video-VSR_%7C_True_HDR-76B900?style=for-the-badge&logo=nvidia&logoColor=white" alt="AI Upscaling"></a>
  <a href="#-the-nvidia-dark-glass-aesthetic"><img src="https://img.shields.io/badge/Design-NVIDIA_Dark_Glass-0A0A0A?style=for-the-badge&logo=materialdesign&logoColor=00E676" alt="Aesthetics"></a>
</p>

An ultra-refined, videophile-grade media environment engineered specifically for Direct3D 11 and NVIDIA RTX architectures. Built on `vo=gpu-next`, this suite delivers zero-copy hardware decoding, judder-free frame pacing for high-refresh displays, tensor-core AI upscaling, studio-grade multichannel acoustic monitoring, a dual-engine film grain controller, and an exclusive vector-rendered glassmorphism user interface.

<p align="center">
  <img width="2000" alt="MPV-RTX Interface Showcase" jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3OTM0NjM2NTYsIm5iZiI6MTc5MzQ2MzM1NiwicGF0aCI6Ii83Njg3NzY2MS82ODM1ODcxOTMtNzBiMjM4OGEtNmM3My00MWRlLTg0MTUtMTcyNzhmZTIyMzE0LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjEwMzElMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYxMDMxVDE2MTU1NlomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTk5NTk5YjM4M2U1MDk2MjI4N2EwNWJhMjQ3YWQ1YTI3YjdjMTdlNjdkOGYxNGU1YTAwNzlkNGRhNTQzM2M2MDkmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0JnJlc3BvbnNlLWNvbnRlbnQtdHlwZT1pbWFnZSUyRnBuZyJ9.xj36shfUUzOOvVwp4Z1FdgY-SDCk-tRRUByqgWqeG24" style="max-width: 100%; border-radius: 6px;">
</p>

---

## 📑 Table of Contents
- [💎 The NVIDIA Dark Glass Aesthetic](#-the-nvidia-dark-glass-aesthetic)
- [⚡ Core Engine & Video Architecture](#-core-engine--video-architecture)
- [🚀 Neural Shaders & AI Upscaling Pipeline](#-neural-shaders--ai-upscaling-pipeline)
- [🎞️ Dual-Engine Film Grain Controller](#️-dual-engine-film-grain-controller)
- [📊 The Diagnostic HUD Suite](#-the-diagnostic-hud-suite)
  - [1. NVIDIA Hardware Monitor (`g`)](#1-nvidia-hardware-monitor-g)
  - [2. Video Diagnostics Monitor (`i` / `I`)](#2-video-diagnostics-monitor-i--i)
  - [3. Studio Audio Monitor (`a`)](#3-studio-audio-monitor-a)
  - [Synchronized Master View (`TAB`)](#synchronized-master-view-tab)
- [🎮 Modern Bottom Bar (OSC)](#-modern-bottom-bar-osc)
- [🎬 Hardware Clip Maker (`W`)](#-hardware-clip-maker-w)
- [🧩 Modular Architecture (`script-modules/`)](#-modular-architecture-script-modules)
- [⌨️ Keybindings Cheatsheet](#️-keybindings-cheatsheet)
- [📦 Installation & Requirements](#-installation--requirements)

---

## 💎 The NVIDIA Dark Glass Aesthetic

Unlike media players that rely on generic flat overlays, MPV-RTX features a bespoke, unified design system rendered via real-time vector ASS overlays:

* **Obsidian Glass Containers (`#0A0A0A` @ ~80% Opacity)**: Clean, translucent frosted backdrop cards that maintain readability over bright, high-contrast video without obstructing playback.
* **Signature NVIDIA Green Accents (`#00E676`)**: Precision top accent borders, tactical progress indicators, and custom vector diamond badges (`◆`) establishing visual hierarchy.
* **RivaTuner Telemetry Cyan (`#00E5FF`)**: High-contrast, eye-fatigue-free readouts for clocks, codecs, timestamps, and demuxer cache buffers.
* **OLED Pure Black (`#000000`)**: Borderless pure black letterboxing and tile disabling (`background=color`, `background-color='#000000'`) engineered to turn off self-lit OLED pixels entirely.
* **Dynamic Anti-Collision Docking**: Toast notifications intelligently reposition to the bottom-center whenever the Studio Audio HUD is active at top-center, eliminating visual overlap.
* **Dynamic DPI Vector Scaling**: Every glyph, vector border, button hitbox, and layout coordinate scales responsively across 1080p, 1440p, 4K UHD, and ultra-wide displays.

---

## ⚡ Core Engine & Video Architecture

* **Direct3D 11 Presentation (`vo=gpu-next`)**: Built on libplacebo with DXGI Flip presentation (`d3d11-flip=yes`), automatic swapchain color space detection (`d3d11-output-csp=auto`), and direct passthrough for Windows Advanced Color/HDR (`target-colorspace-hint=yes`).
* **Zero-Copy Hardware Decoding (`hwdec=d3d11va`)**: Native zero-copy Direct3D 11 video decoding for modern codecs (AV1 10-bit, HEVC, H.264, VP9).
* **Judder-Free Motion Pacing**: Audio-resampling display synchronization (`video-sync=display-resample` with `tscale=oversample` and `interpolation=yes`) eliminates 3:2 pulldown judder, providing cinematic motion smoothness on 60Hz through 240Hz+ displays.
* **High-Order Scalers & Ringing Suppression**: Lanczos luma and chroma scaling paired with `scale-clamp=0.0`, `cscale-clamp=0.0`, and `scale-antiring=0.7` for sharp edge reproduction without ringing artifacts.
* **Optimized Image Viewer Pipeline**: Dedicated `[IMAGE]` profile with `keep-open=always`, `image-display-duration=inf`, and fast bicubic `scale=spline36` with bypass flags for instant, lag-free zoom and pan sweeps across high-resolution photography.

---

## 🚀 Neural Shaders & AI Upscaling Pipeline

Seamlessly toggle between hardware Tensor-core AI upscaling and custom spatial reconstruction compute shaders:

| Hotkey | Upscaler Engine | Processing Tier | Description |
| :---: | :--- | :--- | :--- |
| **`1`** | **NVIDIA RTX VSR** | Hardware Tensor AI | Deep-learning super resolution up to 4.0x via D3D11VPP with isotropic aspect-ratio scaling. |
| **`Alt+1`** | **RTX VSR Update** | Hardware Tensor AI | Forces dynamic re-scaling calculation on window resize or viewport changes. |
| **`2`** | **NVIDIA NIS** | Spatial Compute Shader | Direction-adaptive sharpening and linear upscaling engine (`NVScaler.glsl`). |
| **`3`** | **AMD FSR 1.0** | Spatial Two-Pass Shader | Edge-Adaptive Super Sampling (EASU) + Robust Contrast-Adaptive Sharpening (RCAS) (`FSR.glsl`). |
| **`4`** | **Qualcomm SGSR** | Single-Pass Edge Shader | Direction-aware Lanczos reconstruction tuned for minimal power draw (`SGSR.glsl`). |
| **`5`** | **AMD CAS (Scaled)** | Contrast Reconstruction | Adaptive high-frequency luminance sharpening in linear light (`CAS-scaled.glsl`). |
| **`h`** | **NVIDIA RTX True HDR** | Tensor Core Inverse Tone | Real-time SDR to HDR10 (PQ) conversion with native HDR override protection. |
| **`9`** | **Base Luma Scaler** | Interpolation Fallback | Quickly toggles fallback luma scaler between `lanczos` and `nearest`. |
| **`0`** | **Master Reset** | Clean Fallback | Clears all active shaders, VSR/HDR instances, film grain, audio filters, and geometry offsets. |

---

## 🎞️ Dual-Engine Film Grain Controller

A dedicated film grain subsystem accessible via `6` / `G`:

* **Mode A — AV1 Bitstream FGS Stripping**: Instant toggle to enable or strip normative AV1 Film Grain Synthesis metadata on the fly (`@filmgrain:format=film-grain=no`), allowing comparison between raw denoise-encoded streams and hardware-reconstructed grain.
* **Mode B — Universal GPU Synthetic Grain**: Injects organic film grain into non-AV1 content (H.264, HEVC, SDR/HDR) using mpv's native GPU deband carrier. Operates with `threshold=1` to guarantee **zero detail smoothing** and **0% Gray Lift** (safe for OLED true blacks).
  * **35mm Fine (+32)**: Subtle organic grain layer for clean 4K/1080p masters.
  * **35mm Cinematic (+64)**: Standard filmic aesthetic.
  * **16mm Vintage Indie (+128)**: Pronounced grain for indie and retro material.
  * **8mm Gritty Archive (+256)**: Heavy stylized film grain.
* **Grain Diagnostics HUD (`Alt+6` / `Alt+g`)**: Displays operating mode, engine status, decoder pipeline, and dynamic temporal frequencies.

---

## 📊 The Diagnostic HUD Suite

### 1. NVIDIA Hardware Monitor (`g`)
Direct real-time hardware telemetry polled via non-blocking asynchronous calls:
* **GPU Metrics**: Core clock, memory clock, GPU load, and dedicated NVDEC hardware decoder engine utilization.
* **Thermal & Power**: Die temperature with dynamic color coding, fan tachometers (including Fan Stop mode), real-time board power draw against TDP limits.
* **VRAM Telemetry**: MiB-accurate VRAM utilization and total physical frame buffer capacity.
* **Display Engine**: Physical display refresh rate, container framerate, dropped/mistimed frame counters, GPU render latency in milliseconds, and Windows Variable Refresh Rate (VRR/G-Sync) detection.

### 2. Video Diagnostics Monitor (`i` / `I`)
Deep container, stream, and color science diagnostics:
* **Container & Memory**: File format, physical size, timeline position, chapters, live demuxer cache duration, and RAM buffer occupancy.
* **Video Stream**: Codec details, hardware decoder status (`d3d11va`), film grain status, exact aspect ratio (SAR/DAR), and real-time upscaled output resolution (e.g. `1080x1920 -> 2160x3840`).
* **Color Science**: Bit-depth, pixel format, active color primaries (`BT.709` vs `BT.2020 WCG`), and gamma transfer curves (`BT.1886`, `sRGB`, `HDR10 PQ`, `HLG`, with dynamic SDR-to-HDR progression tracking).

### 3. Studio Audio Monitor (`a`)
Audiophile and multichannel acoustic telemetry suite (automatically activates on music playback):
* **Dynamic 7.1 Speaker Matrix**: Physical 3x3 vector grid displaying real-time speaker activity (`FL`, `C`, `FR`, `SL`, `LFE`, `SR`, `BL`, `BR`).
* **Hardware Acoustic Parameters**: Bit-perfect sample rates (e.g. `48.000 Hz`), audio bit-depth (`16-bit`, `24-bit`, `32-bit Float`), bitrate, active audio output device, and millisecond-accurate A/V sync drift.
* **Headphone DSP Presets (`A`)**: One-key cycling through 7.1 Spatial Audio Expander, Bauer BS2B Binaural Crossfeed, Stereo Soundstage Expander, and Dynamic Normalizer (Night Mode).
* **Zero-Clipping Bass Boost (`b`)**: Audiophile low-end equalizers with negative pre-attenuation headroom to eliminate digital clipping (`Clean Warmth +4dB`, `Deep Punch +7dB`, `Sub-Bass Club +10dB`).
* **Channel Soloing (`B` / `Ctrl+1-5,0`)**: Real-time layout-adaptive channel isolation: dialogue (`Center`), music score (`Front L/R`), surround FX, rear backs, or subwoofer (`LFE`).

### Synchronized Master View (`TAB`)
Pressing `TAB` invokes a synchronized master toggle that opens or closes both the **Video Diagnostics Monitor** (left) and the **NVIDIA Hardware Monitor** (right) simultaneously with 0ms redraw coalescing and zero state desynchronization.

---

## 🎮 Modern Bottom Bar (OSC)

A completely standalone on-screen controller engineered with decoupled mouse interaction:

* **Decoupled 60 FPS Render Loop**: Scrubbing and timeline tracking remain decoupled from mpv's main event queue, preventing drag latency or stuck sliders.
* **Unified Window Dragging**: Clicking and dragging anywhere on the video canvas initiates native window dragging (`begin-vo-dragging`), while timeline scrubbing, menu clicks, and volume adjustments remain isolated from accidental window movement.
* **Live Telemetry Badges**: Real-time right-docked badges for active resolution scaling (`1080p -> 4K`), HW/SW decoder, Film Grain status (`[FGS: ON/OFF]` or `[GRAIN]`), Scaler Engine, and Dynamic Range (`SDR` / `RTX TRUE HDR` / `HDR10 (PQ)` / `HLG`).
* **Interactive Audio & Subtitle Popups**: Clicking on the audio or subtitle badges opens a floating glass menu with full track details (codecs, channel configurations, languages, and forced subtitle tags).
* **Clickable Volume Slider Bar**: Click or drag directly on the volume slider, click the volume badge to toggle instant mute, or use the mouse wheel over the bar for ±2% volume adjustments.
* **Interactive Chapter Marks**: Subtle chapter ticks across the timeline with floating chapter title tooltips on hover.
* **Mutual Exclusion**: Automatically suppresses itself when the Hardware Clip Maker is active.

---

## 🎬 Hardware Clip Maker (`W`)

A built-in video clipping and encoding utility rendered cleanly in the bottom-left viewport:

* **NVENC Hardware Acceleration**: High-speed trimming and encoding powered by NVIDIA NVENC (`avc-nvenc`, `hevc-nvenc`, `av1-nvenc`) and CPU fallbacks (`x264`, `x265`, `vp9`, `gif`).
* **Hardened Stability (`bf=0`)**: Enforces zero B-frames on NVENC MP4 muxing to completely eliminate packet timestamp crashes (`pts < dts in stream 0`).
* **Automatic 10-Bit Color Pipeline Adaptation**: Injects `format=yuv420p` for H.264 exports from 10-bit AV1 or HDR sources, avoiding unsupported pixel format failures.
* **Even Dimension Clamping**: Restricts interactive crop boundaries and output scaling to even integer values (`% 2 == 0`) to satisfy encoder requirements.
* **Interactive Crop & In-Player Preview**: Visual crop region selector with mouse coordinate picking and seamless A-B loop preview before rendering.
* **Portable Binary Auto-Discovery**: Automatically detects local `mpv.exe` or Unix binaries inside portable directory setups.

---

## 📜 Credits & License
* **Core Player**: [mpv](https://mpv.io) — copyright mpv developers.
* **Scalers & Shaders**:
  * NVIDIA Image Scaling (NIS) — NVIDIA Corporation.
  * FidelityFX FSR & CAS — Advanced Micro Devices, Inc.
  * Snapdragon GSR — Qualcomm Innovation Center, Inc.
  * GLSL shader ports by [agyild](https://github.com/agyild/mpv-shaders).
* **Suite Architecture**: Built and maintained by [askasys-code](https://github.com/askasys-code).
* **License**: Released under the [MIT License](LICENSE).
