# IPScannerGUI

A lightweight Windows IP Scanner with a modern graphical user interface.  
Built entirely in PowerShell and compiled into a portable Windows executable.

This tool allows administrators, power users, network technicians, and home users to quickly scan local subnets, detect active devices, identify hostnames, analyze MAC manufacturers, read HTTP banners/titles, calculate ping averages, and export results to CSV – all with a clean GUI and convenient controls.

---

## 🚀 Features

### ✔ IP Scanning
- Scan any IP range (manual or predefined)
- Fast ping detection (2 pings per host)
- Pause & resume scanning
- Stop scan immediately

### ✔ Device Identification
- Hostname detection (DNS reverse lookup)
- MAC address parsing via ARP
- MAC vendor lookup (Shelly, AVM, Apple, Intel, Samsung, TP-Link, Ubiquiti, Xiaomi, etc.)
- HTTP banner reading  
  → Detects web interfaces & server headers  
  → Extracts `<title>` from web UI (e.g., routers, cameras, IoT devices)

### ✔ Export & Reporting
- Export results to CSV (semicolon-separated for Excel compatibility)
- Option to export **only online devices** or **all scanned devices**
- Optional auto-open CSV after scanning

### ✔ GUI Highlights
- Clean, simple and responsive Windows Forms interface
- Predefined network ranges (192.168.0.x, 1.x, 178.x)
- Custom ranges
- Status panel + real-time log
- “About” dialog with clickable email and Ko-fi support link
- Icon support (compiled into EXE)

### ✔ Update System
- Automatic check for updates on GitHub
- Compares local version with `version.txt` in the repository
- Opens latest release page when a new version is available

### ✔ Portable
- Fully portable EXE  
- No installation required  
- Runs without admin rights  
- Zero dependencies (PowerShell runtime built into Windows)

---

## 📥 Download

👉 **Latest Release:**  
https://github.com/Tripl389/IPScannerGUI/releases/latest

Download the file:

