# Projectum Lunare Forge

> **Unified Build, Toolchain & Cross-Compilation Addon for Xmake**  
> Architected for retro, embedded, and modern systems across the Projectum Lunare ecosystem.

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Build System: Xmake](https://img.shields.io/badge/Build%20System-Xmake-red.svg)](https://xmake.io)

---

## Overview

**Forge** is the official build infrastructure and cross-compilation engine for **Projectum Lunare** (powering [`solo`](https://github.com/projectum-lunare/solo), [`dotstar`](https://github.com/projectum-lunare/dotstar), and other systems).

Instead of reinventing low-level DAG build graphs from scratch, Forge integrates natively into [Xmake](https://xmake.io) as a modular addon, providing:

- **Formal Custom Platforms:** First-class declarations for vintage systems (`amiga`, `atari`, `kolibri`, `dos`, `os2`, `wince`) and distinct modern BSD platforms (`freebsd`, `openbsd`, `netbsd`, `dragonflybsd`).
- **Automatic Default Architectures:** Automatic mappings (`amiga|m68k`, `atari|m68k`, `kolibri|i386`, `dos|i386`, `os2|i386`, `wince|arm`, `freebsd|x86_64`, `openbsd|x86_64`, `netbsd|x86_64`, `dragonflybsd|x86_64`).
- **Native Compiler Rules:** Direct execution of non-standard toolchains (`Open Watcom` v2 for DOS/OS2 via `owcc`/`wlib`, `Microsoft eVC 3.0` via `wibo`) using native Xmake batch commands without brittle shell/Python wrapper scripts.
- **Cross-Platform SDK Detection:** Automatic resolution across Unix (`~/.local/opt/<sdk>`) and Windows (`%APPDATA%`, `%LOCALAPPDATA%`).
- **First-Class Lua Subsystem (LuaRocks Alternative):** Native project management for pure Lua libraries, native C extensions (`.so`/`.dll` and static retro archives), portable executable launchers, monolithic single-binary bundlers, and zero-friction isolated environments (`LUA_PATH`/`LUA_CPATH`).
- **Matrix Orchestration CLI:** High-level `xmake forge` tasks to audit, cross-compile, and benchmark builds across target architectures.

---

## Supported Platforms & Toolchains

| Platform            | Target OS           | Default Arch         | Supported Architectures (Xmake Normalized)                                                                         | Toolchain   | Toolset / Compiler                              | SDK Fallback                 |
| :------------------ | :------------------ | :------------------- | :----------------------------------------------------------------------------------------------------------------- | :---------- | :---------------------------------------------- | :--------------------------- |
| **`amiga`**         | AmigaOS Classic     | `m68k`               | `m68k`                                                                                                             | `amigaos`   | Bebbo GCC (`m68k-amigaos-gcc`)                  | `~/.local/opt/amigaos-sdk`   |
| **`atari`**         | Atari ST / FreeMiNT | `m68k`               | `m68k`                                                                                                             | `atarist`   | FreeMiNT GCC (`m68k-atari-mint-gcc`)            | `~/.local/opt/atarist-sdk`   |
| **`kolibri`**       | KolibriOS           | `i386`               | `i386`                                                                                                             | `kolibrios` | KolibriOS GCC (`kos32-gcc`)                     | `~/.local/opt/kolibrios-sdk` |
| **`dos`**           | MS-DOS 32-bit       | `i386`               | `i386`                                                                                                             | `watcom`    | Open Watcom v2 (`owcc -b dos32a`)               | `~/.local/opt/watcom`        |
| **`os2`**           | OS/2 32-bit Warp    | `i386`               | `i386`                                                                                                             | `watcom`    | Open Watcom v2 (`owcc -b os2v2`)                | `~/.local/opt/watcom`        |
| **`wince`**         | Windows CE 3.0      | `arm`                | `arm`, `mips`, `ppc`, `sh3`, `sh4`, `x86`                                                                          | `evc3`      | MS eVC 3.0 (`clarm.exe`, `shcl.exe` via `wibo`) | `~/.local/opt/evc3`          |
| **`freebsd`**       | FreeBSD             | `x86_64`             | `x86_64`, `i386`, `arm64`, `armv7`, `ppc`, `ppc64`, `ppc64le`, `ppcspe`, `riscv64`                                | `clang/gcc` | System / LLVM Clang, GCC                        | Host Native / Cross-Tools    |
| **`openbsd`**       | OpenBSD             | `x86_64`             | `x86_64`, `i386`, `arm64`, `armv7`, `alpha`, `hppa`, `m88k`, `mips64`, `ppc`, `ppc64`, `riscv64`, `sh4`, `sparc64`| `clang/gcc` | System / LLVM Clang, GCC                        | Host Native / Cross-Tools    |
| **`netbsd`**        | NetBSD              | `x86_64`             | `x86_64`, `i386`, `arm`, `arm64`, `alpha`, `hppa`, `ia64`, `m68k`, `m68010`, `mips`, `mips64`, `mipseb`, `mipsel`, `ppc`, `ppc64`, `riscv32`, `riscv64`, `sh3`, `sh3eb`, `sh3el`, `sparc`, `sparc64`, `vax` | `gcc/clang` | System GCC, LLVM Clang                          | Host Native / Cross-Tools    |
| **`dragonflybsd`**  | DragonFly BSD       | `x86_64`             | `x86_64`                                                                                                           | `gcc/clang` | System GCC, LLVM Clang                          | Host Native / Cross-Tools    |
| **`linux`**         | Linux / POSIX Host  | `x86_64`             | `x86_64`, `i386`, `arm64`, `armv7`, `riscv64`, `ppc64le`, etc.                                                     | `host`      | System Clang / GCC                              | Host Native                  |

### First-Class BSD Platforms & Architecture Normalization

Standard Xmake merges all BSD distributions into a single generic `bsd` platform. Forge separates them into first-class targets (`freebsd`, `openbsd`, `netbsd`, and `dragonflybsd`) while normalizing official upstream architecture names into canonical Xmake identifiers:

- **FreeBSD** ([Official Releases](https://www.freebsd.org/where/)):
  - `amd64` &rarr; `x86_64` | `i386` &rarr; `i386` | `aarch64` &rarr; `arm64` | `armv7` &rarr; `armv7`
  - `powerpc` &rarr; `ppc` | `powerpc64` &rarr; `ppc64` | `powerpc64le` &rarr; `ppc64le` | `powerpcspe` &rarr; `ppcspe` | `riscv64` &rarr; `riscv64`
- **OpenBSD** ([Official FAQ #4 Platforms](https://www.openbsd.org/faq/faq4.html#Download)):
  - `alpha` &rarr; `alpha` | `amd64` &rarr; `x86_64` | `arm64` &rarr; `arm64` | `armv7` &rarr; `armv7` | `hppa` &rarr; `hppa` | `i386` &rarr; `i386`
  - `landisk` (SuperH SH4) &rarr; `sh4` | `luna88k` (Motorola 88k) &rarr; `m88k` | `macppc` (PowerPC 32) &rarr; `ppc`
  - `octeon` (MIPS64) &rarr; `mips64` | `powerpc64` &rarr; `ppc64` | `riscv64` &rarr; `riscv64` | `sparc64` &rarr; `sparc64`
- **DragonFly BSD** ([Official Releases](https://www.dragonflybsd.org/download/)):
  - Pure 64-bit x86 &rarr; `x86_64` (alias `dragonfly` also supported)
- **NetBSD** ([Official Ports Wiki](https://wiki.netbsd.org/ports/)):
  - `amd64` &rarr; `x86_64` | `i386` &rarr; `i386` | `aarch64` &rarr; `arm64` | `arm` &rarr; `arm`
  - `mips` &rarr; `mips`, `mips64`, `mipseb`, `mipsel` | `powerpc` &rarr; `ppc`, `ppc64`
  - `alpha` &rarr; `alpha` | `m68k` &rarr; `m68k` | `m68010` &rarr; `m68010` | `itanium` &rarr; `ia64`
  - `riscv` &rarr; `riscv32`, `riscv64` | `sparc` &rarr; `sparc`, `sparc64` | `vax` &rarr; `vax` | `hppa` &rarr; `hppa`
  - `sh3 (sh3eb / sh3el)` &rarr; `sh3`, `sh3eb`, `sh3el`

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

### Vintage Compiler Rules (`forge.watcom` & `forge.evc3`)

For vintage targets with specialized proprietary toolchains, attach the native compilation rules:
```lua
target("my_retro_app")
    set_kind("binary")
    add_files("src/*.c")

    -- Open Watcom v2 C compiler & linker (DOS 32-bit & OS/2 Warp)
    if is_plat("dos", "os2") then
        add_rules("forge.watcom", {override = true})
    -- Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
    elseif is_plat("wince") then
        add_rules("forge.evc3", {override = true})
    end
```
*(Standard platforms like `amiga`, `atari`, `kolibri`, `freebsd`, `openbsd`, `netbsd`, `dragonflybsd`, and `linux` use native GCC/Clang toolchains automatically with standard Xmake C/C++ build graphs).*


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
