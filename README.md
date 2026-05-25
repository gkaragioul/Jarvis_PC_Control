# Jarvis PC Control

Jarvis PC Control is a macOS menu-bar utility for managing the remote Jarvis Windows PC from a Mac.

It is built as a small Swift/AppKit app that lives in the macOS status bar as `J`. The app gives fast access to the remote machine, Ollama health, model warm/offload actions, SSH, Chrome Remote Desktop, and live machine stats.

## What It Does

- Shows whether the remote PC and Ollama are reachable.
- Displays CPU, memory, GPU, VRAM, temperature, power, uptime, and X: drive space stats.
- Warms the configured Ollama model so local Jarvis responses stay responsive.
- Offloads the model when the PC should release GPU memory.
- Opens SSH and Chrome Remote Desktop shortcuts.
- Installs itself into `/Applications`, updates the Dock icon, creates a Desktop alias, and registers a LaunchAgent so it starts when the Mac logs in.

## Current Assumptions

- Remote PC host: `jarvis-pc`
- Ollama API: `http://jarvis-pc:11434`
- Jarvis storage target on the PC: `X:\`
- macOS app install target: `/Applications/JarvisPCControl.app`
- Wake-on-LAN target MAC: `04:7C:16:BA:A2:FC`

## Build

```bash
swift build
```

## Install Locally

```bash
Tools/install.sh
```

The installer rebuilds the app, regenerates the app icon, replaces the copy in `/Applications`, refreshes the Dock entry, updates the Desktop alias, and reloads the login LaunchAgent.

## Wake-on-LAN

The app includes a Wake button that sends magic packets for the PC Ethernet adapter.

Wake-on-LAN is configured in Windows for the Realtek Ethernet adapter, but full shutdown wake also depends on BIOS/UEFI and network routing. The PC BIOS should have Wake-on-LAN or PCIe wake enabled, ErP/deep sleep disabled, and optionally restore power after AC loss enabled.

## Repository

This repository tracks the source and install tooling for Jarvis PC Control. Build products and generated `.app` bundles are intentionally excluded.
