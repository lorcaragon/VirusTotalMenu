# VirusTotal Context Menu

A simple Windows right-click context menu tool that lets you scan any file directly on [VirusTotal](https://www.virustotal.com) by right-clicking it and selecting **"Scan with VirusTotal"**. The result is shown as a clean notification popup.

## Features

- Adds a **"Scan with VirusTotal"** entry to the right-click menu
- Looks up the file's SHA256 hash in the VirusTotal database
- If the file isn't found, it's automatically uploaded to VirusTotal and the analysis is awaited
- Shows a color-coded/iconed notification based on the detection count (Clean / Suspicious / High Risk)
- "View Report" button opens the full VirusTotal report in your browser

## Requirements

- Windows 10/11
- A free [VirusTotal API key](https://www.virustotal.com/gui/my-apikey) (log in to your VirusTotal account and grab it from the "API Key" page)

## Installation

1. Download all the files in this repository into a single folder on your computer (`Install.ps1`, `Uninstall.ps1`, `VTCheck.ps1`, `VTCheck.vbs`, and the `.bat` files must all be in the same folder).
2. Double-click **`1 - Install VirusTotal Context Menu.bat`**.
3. When prompted, paste your VirusTotal API key and press Enter.
   - The key is saved encrypted at `%LOCALAPPDATA%\VirusTotalMenu\apikey.dat`.
4. Once you see "Installation completed successfully!", setup is done.

You'll now see **"Scan with VirusTotal"** when right-clicking any file.

## Usage

1. Right-click the file you want to scan.
2. Select **Scan with VirusTotal**.
3. If the file has already been scanned on VirusTotal before, the result appears within a few seconds.
4. If the file isn't in the database yet, it's uploaded automatically and you'll get notifications while the analysis runs (this can take a few minutes depending on VirusTotal's servers).
5. Click **"View Report"** in the result popup to open the full report in your browser.

## Uninstallation

Double-click **`2 - Uninstall VirusTotal Context Menu.bat`**. The context menu entry is removed, and you'll be asked whether you also want to delete the install folder (`%LOCALAPPDATA%\VirusTotalMenu`).

---

*This project is entirely vibe coded.*
