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
| **`wince`**         | Windows CE 3.0      | `arm`                | `arm`, `mips`, `ppc`, `sh3`, `sh4`, `x86`                                                                          | `evc3`      | MS eVC 3.0 (`clarm.exe`, `link.exe`, `lib.exe` via `wibo`) | `~/.local/opt/evc3`          |
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
        -- For console apps using standard main() instead of GUI WinMain():
        -- set_values("evc3.entry", "mainACRTStartup")
    end
```
*(Standard platforms like `amiga`, `atari`, `kolibri`, `freebsd`, `openbsd`, `netbsd`, `dragonflybsd`, and `linux` use native GCC/Clang toolchains automatically with standard Xmake C/C++ build graphs).*

> [!NOTE]
> **Windows CE Entry Point:** By default, executables built with `forge.evc3` target the CE graphical subsystem and use `/entry:WinMainCRTStartup` (which invokes `WinMain`). If you are compiling a console / CLI application with a standard `main()`, set the entry point to `mainACRTStartup`:
> ```lua
> set_values("evc3.entry", "mainACRTStartup")
> -- or: add_ldflags("/entry:mainACRTStartup")
> ```


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

### 6. Lua modules as xmake packages

Forge treats a Lua module as an xmake package. There is no rockspec. Including Forge registers the local repository `forge-lua` (`repository/`). A recipe lists its modules and calls `lua.package.install`. `require` finds them through `LUA_PATH` and `LUA_CPATH`.

#### Pure Lua (`.lua` only)

A project made only of `.lua` files does not compile C and does not require the `lua` package. `xmake run` uses a Lua `>= 5.4` interpreter from `PATH` or `LUA_BIN`. Dependencies are pure Lua recipes such as `forge-hello`:

```lua
add_requires("forge-hello")

target("app")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("forge-hello")
```

The matching recipe copies each file into `share/lua/<version>/` and publishes nothing for the linker. `set_kind("library", {headeronly = true})` and `on_fetch` tell xmake that the package has no C library:

```lua
package("my-mod")
    set_kind("library", {headeronly = true})
    set_sourcedir(path.join(os.scriptdir(), "src"))

    on_install(function (package)
        import("lua.package", {alias = "lua_package"}).install(package, {
            modules = {
                ["my.mod"] = "mod.lua"
            }
        })
    end)

    on_fetch(function (package, opt)
        return import("lua.package", {alias = "lua_package"}).fetch(package, opt)
    end)
```

`forge.lua.bundle` is the step that leaves pure Lua: it generates a C executable, so that target needs the `lua` package even when every script is `.lua`.

#### Pure Lua project, C recipe

The project stays `.lua` only. The link mode is the project's:

```bash
xmake f --kind=shared   # dynamic: shared liblua and .so/.dll
xmake f --kind=static   # static: archives only, the default
```

That choice applies to the targets and to every package dependency. Amiga, Atari, KolibriOS, DOS, OS/2, Windows CE and Wasm stay static even with `--kind=shared`, because they cannot `dlopen`.

In dynamic mode the recipe records the Lua package directory. `xmake run` copies the interpreter, `liblua` and the modules into `build/bin/<app>.runtime`. `bin/lua` puts `../lib` on the loader path. `LUA_PATH` and `LUA_CPATH` do not fall through to the system tree. Copy `build/bin/<app>` together with `build/bin/<app>.runtime`.

```lua
add_requires("forge-native")

target("app")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("forge-native")
```

In static mode there is no `.so`. `forge.lua.bundle` links the static `luaopen_*` and `liblua.a` into one executable.

#### Native modules

A C module follows the same `--kind`. Shared mode installs `.so` or `.dll`. Static mode installs only the archive and `forge.lua.bundle` links `luaopen_*`. Amiga, Atari, KolibriOS, DOS, OS/2, Windows CE and Wasm install the archive in either mode.

```lua
add_requires("lua", {system = false})
add_requires("forge-hello", "forge-native")

target("app")
    add_rules("forge.lua.app")
    set_values("forge.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("lua", "forge-hello", "forge-native")
```

`forge-hello` and `forge-native` in `repository/` are the reference recipes. `forge-native` points at `src/native.c`. A new recipe lives at `packages/<initial>/<name>/xmake.lua`. A string that ends in `.c` or `.lua`, or names a file on disk, is a path. Any other string is the source text: Forge writes it to a temporary file and compiles or installs that file. Another recipe tree is registered with `add_repositories("my-lua /path/to/repo")`.

---

## CLI Usage

### Check SDK Status & Toolchain Matrix
```bash
xmake forge list
```

### Build for a Specific Target
Target builds are isolated by default into `build/<target>` (e.g. `build/dos`, `build/amiga`), preserving independent configurations and artifacts:
```bash
xmake forge amiga
xmake forge atari
xmake forge kolibri
xmake forge dos
xmake forge os2
xmake forge wince
xmake forge freebsd
xmake forge posix

# To disable build directory isolation and build into root build/:
xmake forge dos --no-isolate
```

### Run Full Multi-Platform Matrix Build
```bash
xmake forge all
```

---

## License

Mozilla Public License Version 2.0 (MPL-2.0). See [LICENSE](LICENSE) for details.
