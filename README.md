# Projectum Lunare Forge

> **Unified Build, Toolchain & Cross-Compilation Addon for Xmake**  
> Architected for retro, embedded, and modern systems across the Projectum Lunare ecosystem.

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Build System: Xmake](https://img.shields.io/badge/Build%20System-Xmake-red.svg)](https://xmake.io)

---

## Overview

**Forge** is the official build infrastructure and cross-compilation engine for **Projectum Lunare** (powering [`solo`](https://github.com/projectum-lunare/solo), [`dotstar`](https://github.com/projectum-lunare/dotstar), and other systems).

Instead of reinventing low-level DAG build graphs from scratch, Forge integrates natively into [Xmake](https://xmake.io) as a modular addon, providing:

- **Formal Custom Platforms:** First-class declarations for `amiga`, `atari`, `kolibri`, `dos`, `os2`, and `wince`.
- **Automatic Default Architectures:** Automatic mappings (`amiga|m68k`, `atari|m68k`, `kolibri|i386`, `dos|i386`, `os2|i386`, `wince|arm`).
- **Native Compiler Rules:** Direct execution of non-standard toolchains (`Open Watcom` v2 for DOS/OS2 via `owcc`/`wlib`, `Microsoft eVC 3.0` via `wibo`) using native Xmake batch commands without brittle shell/Python wrapper scripts.
- **Cross-Platform SDK Detection:** Automatic resolution across Unix (`~/.local/opt/<sdk>`) and Windows (`%APPDATA%`, `%LOCALAPPDATA%`).
- **Matrix Orchestration CLI:** High-level `xmake forge` tasks to audit, cross-compile, and benchmark builds across target architectures.

---

## Supported Platforms & Toolchains

| Platform | Target OS | Default Arch | Toolchain | Toolset / Compiler | SDK Fallback |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`amiga`** | AmigaOS Classic | `m68k` | `amigaos` | Bebbo GCC (`m68k-amigaos-gcc`) | `~/.local/opt/amigaos-sdk` |
| **`atari`** | Atari ST / FreeMiNT | `m68k` | `atarist` | FreeMiNT GCC (`m68k-atari-mint-gcc`) | `~/.local/opt/atarist-sdk` |
| **`kolibri`**| KolibriOS | `i386` | `kolibrios`| KolibriOS GCC (`kos32-gcc`) | `~/.local/opt/kolibrios-sdk` |
| **`dos`** | MS-DOS 32-bit | `i386` | `watcom` | Open Watcom v2 (`owcc -b dos32a`) | `~/.local/opt/watcom` |
| **`os2`** | OS/2 32-bit Warp | `i386` | `watcom` | Open Watcom v2 (`owcc -b os2v2`) | `~/.local/opt/watcom` |
| **`wince`** | Windows CE 3.0 | `arm` (sh3/sh4/mips) | `evc3` | MS eVC 3.0 (`clarm.exe`, `shcl.exe` via `wibo`) | `~/.local/opt/evc3` |
| **`linux`** | Linux / POSIX Host | `x86_64` | `host` | System Clang / GCC | Host Native |

---

## Installation

Install Forge directly via Xmake:
```bash
xmake addon --install github:projectum-lunare/forge
```

---

## Usage in Projects (`xmake.lua`)

Declare Forge as a project addon dependency:
```lua
add_addons("forge")
includes("@addon/forge/forge.lua")
```

> **Note:** For offline or monorepo development, vendoring Forge as a git submodule (`vendor/forge`) or sibling directory (`../forge`) is also supported:
> ```lua
> if os.isdir("vendor/forge") then
>     includes("vendor/forge")
> elseif os.isdir("../forge") then
>     includes("../forge")
> else
>     add_addons("forge")
>     includes("@addon/forge/forge.lua")
> end
> ```

---

## CLI Usage

### Check SDK Status & Toolchain Matrix
```bash
xmake forge list
```

### Build for a Specific Target
```bash
xmake forge amiga
xmake forge atari
xmake forge kolibri
xmake forge dos
xmake forge os2
xmake forge wince
```

### Run Full Multi-Platform Matrix Build
```bash
xmake forge all
```

---

## License

Mozilla Public License Version 2.0 (MPL-2.0). See [LICENSE](LICENSE) for details.
