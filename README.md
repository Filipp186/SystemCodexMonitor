# System & Codex Monitor

[![Build](https://github.com/Filipp186/SystemCodexMonitor/actions/workflows/build.yml/badge.svg)](https://github.com/Filipp186/SystemCodexMonitor/actions/workflows/build.yml)

[Русская версия](README.ru.md)

An unofficial extension for the Microsoft PowerToys Command Palette Dock. It keeps eight live values in a compact four-icon band:

- Codex remaining usage limit;
- CPU package temperature and load;
- RAM DIMM temperature and physical-memory load;
- GPU temperature, load, and VRAM usage.

Values are shown on one line. Hover an item to see labeled details and Codex reset times.

## Requirements

- Windows 11 x64;
- PowerToys Command Palette with Dock support;
- Windows Developer Mode for the ZIP installation;
- AIDA64 running with **Preferences → External Applications → Enable shared memory**;
- Codex CLI signed in, installed at `%USERPROFILE%\.codex\plugins\.plugin-appserver\codex.exe` or in an absolute directory on `PATH`.

CPU, RAM, and GPU temperatures are read from AIDA64 shared memory, with LibreHardwareMonitor fallback when readings are unavailable. Hardware load is read through LibreHardwareMonitor. Codex limits are read locally through `codex app-server`; the extension does not read or store account tokens. Executables are resolved to full paths; relative `PATH` entries and the current directory are not searched implicitly.

## Install

1. Download `SystemCodexMonitor-v0.1.5-win-x64.zip` and its `.sha256` file from [Releases](https://github.com/Filipp186/SystemCodexMonitor/releases/latest). Compare `Get-FileHash <zip> -Algorithm SHA256` with the checksum before extracting. This detects corruption, not a compromised release account.
2. Extract the ZIP.
3. Run `Install.cmd`.
4. Open Command Palette settings, enable **System & Codex Monitor**, then enable the **System sensors** and **Codex limit** Dock bands.
5. In Dock edit mode, disable subtitles for the compact one-line layout.

The installer copies the application to `%LOCALAPPDATA%\Programs\SystemCodexMonitor`. It also registers a delayed logon check that restarts Command Palette only when its Dock window did not appear after display initialization. The extracted ZIP can then be deleted.

To remove the extension, run `Uninstall.cmd` from the release ZIP.

## Build

Requirements: .NET 10 SDK and Windows SDK 10.0.26100.

```powershell
dotnet restore SystemCodexMonitor.sln
dotnet build SystemCodexMonitor.sln -c Release -p:Platform=x64
```

Create a distributable ZIP:

```powershell
.\scripts\New-Release.ps1 -Version 0.1.5
```

## Notes

- Release ZIPs omit PDB debug symbols and local source paths. Dependency licenses remain included.
- Restore audits direct and transitive NuGet packages; known vulnerability warnings fail the build.
- Hardware values refresh every two seconds; Codex limits refresh every two minutes.
- AIDA64 must remain running for CPU and RAM temperature readings.
- This project is not affiliated with Microsoft, FinalWire, or OpenAI.
- OpenAI and Codex names and marks belong to OpenAI and are not covered by this repository's MIT license.

See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for dependency licenses.
