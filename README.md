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

## Build

```bash
swift build
```

## Install Locally

```bash
Tools/install.sh
```

The installer rebuilds the app, regenerates the app icon, replaces the copy in `/Applications`, refreshes the Dock entry, updates the Desktop alias, and reloads the login LaunchAgent.

## Repository

This repository tracks the source and install tooling for Jarvis PC Control. Build products and generated `.app` bundles are intentionally excluded.
