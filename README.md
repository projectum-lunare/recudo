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
- **First-Class Lua Subsystem (LuaRocks Alternative):** Native project management for pure Lua libraries, native C extensions (`.so`/`.dll` and static retro archives), portable executable launchers, monolithic single-binary bundlers, and zero-friction isolated environments (`LUA_PATH`/`LUA_CPATH`).
- **Matrix Orchestration CLI:** High-level `xmake forge` tasks to audit, cross-compile, and benchmark builds across target architectures.

---

## Supported Platforms & Toolchains

| Platform      | Target OS           | Default Arch         | Toolchain   | Toolset / Compiler                              | SDK Fallback                 |
| :------------ | :------------------ | :------------------- | :---------- | :---------------------------------------------- | :--------------------------- |
| **`amiga`**   | AmigaOS Classic     | `m68k`               | `amigaos`   | Bebbo GCC (`m68k-amigaos-gcc`)                  | `~/.local/opt/amigaos-sdk`   |
| **`atari`**   | Atari ST / FreeMiNT | `m68k`               | `atarist`   | FreeMiNT GCC (`m68k-atari-mint-gcc`)            | `~/.local/opt/atarist-sdk`   |
| **`kolibri`** | KolibriOS           | `i386`               | `kolibrios` | KolibriOS GCC (`kos32-gcc`)                     | `~/.local/opt/kolibrios-sdk` |
| **`dos`**     | MS-DOS 32-bit       | `i386`               | `watcom`    | Open Watcom v2 (`owcc -b dos32a`)               | `~/.local/opt/watcom`        |
| **`os2`**     | OS/2 32-bit Warp    | `i386`               | `watcom`    | Open Watcom v2 (`owcc -b os2v2`)                | `~/.local/opt/watcom`        |
| **`wince`**   | Windows CE 3.0      | `arm` (sh3/sh4/mips) | `evc3`      | MS eVC 3.0 (`clarm.exe`, `shcl.exe` via `wibo`) | `~/.local/opt/evc3`          |
| **`linux`**   | Linux / POSIX Host  | `x86_64`             | `host`      | System Clang / GCC                              | Host Native                  |

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

---

## Lua Subsystem (Modern LuaRocks Alternative)

Forge provides a first-class build and execution system for Lua 5.4+ projects without requiring external package managers:

### 1. Pure Lua Module (`forge.lua.module`)
Automatically stages and packages `.lua` source files into `build/lua/` with canonical paths:
```lua
target("mylib")
    add_rules("forge.lua.module")
    add_files("src/**.lua")
```

### 2. Native C & Hybrid Modules
Compiles C code into Lua-loadable shared modules (`.so` / `.dll`) on modern OSes or static archives on vintage platforms. The linkage mode can be automatic or explicitly specified:
```lua
-- Shared module (default on desktop: Linux, macOS, Windows)
target("mylib.native")
    add_rules("forge.lua.module")
    add_files("src/native/*.c")

-- Static module (default on vintage targets, or forced for static embedding)
target("mylib.static")
    set_kind("static") -- or: set_values("forge.lua.kind", "static")
    add_rules("forge.lua.module")
    add_files("src/native/*.c")
```

### 3. Application Launcher (`forge.lua.app`)
Generates standalone portable shell (`sh`) / batch (`cmd`) launchers in `build/bin/<app>` and supports instant execution via `xmake run`:
```lua
target("my_app")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_deps("mylib", "mylib.native")
```

Run directly:
```bash
xmake run my_app --help
./build/bin/my_app --help
```

### 4. Monolithic Standalone Bundler (`forge.lua.bundle`)
Embeds Lua runtime and compiles all Lua scripts directly into ANSI C byte arrays via an ERB-style template engine, generating a single self-contained native executable with zero external dependencies:
```lua
target("my_standalone_app")
    add_rules("forge.lua.bundle")
    add_files("src/**.lua")
    set_values("forge.lua.entry", "src/main.lua")

    -- Optional: supply a custom C template for specialized runtimes (e.g., SDL, Watcom GUI)
    -- set_values("forge.lua.template", "src/custom_main.c.in")
```

### 5. Environment & IDE Integration (`xmake forge env`)
Export project-local `LUA_PATH` and `LUA_CPATH` without global pollution:
```bash
# Set environment in current shell session (like luarocks path)
eval $(xmake forge env)

# Export .env file for VS Code, Neovim & LuaLS (Language Server)
xmake forge env --export-env
```

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
