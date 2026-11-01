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
- **Universal Multi-Runtime Engine (`@addon.forge.lua.runtime`):** Declarative orchestration of PUC-Lua, LuaJIT, and OpenResty dependencies with automated ABI buildhash isolation and semver constraints.
- **Interactive Development & Scaffolding:** Instant REPL with project-aware environment (`xmake forge repl`) and canonical scaffolding templates (`xmake forge create`).
- **LÖVE 2D Game Engine Integration (`forge.engine.love`):** Native rule for game development, dynamic C-extension preloading without boilerplate, fast local dev runs, and release-ready fused standalone binaries.
- **Amulet Game Toolkit Integration (`forge.engine.amulet`):** Native rule for 2D/3D audio/visual games, dynamic C-extension preload hook into Amulet's runtime, instant development iteration, and standalone release bundle packaging (`data.pak`).
- **Teal Typed Lua Integration (`forge.lang.teal`):** Native rule providing gradual static typing, strict type-checking, and transpilation into clean Lua.
- **Nelua Systems Language Integration (`forge.lang.nelua`):** Native rule compiling statically-typed, meta-programmable systems code directly to ANSI/C99 (for vintage & modern toolchains) or clean Lua.
- **Compile-to-Lua Transpilers (`forge.lang.*`):** Native `forge.lang.fennel`, `forge.lang.moonscript`, and `forge.lang.yuescript` rules providing seamless Ahead-of-Time (AOT) transpilation of `.fnl`, `.moon`, and `.yue` files into clean Lua code.
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

### Vintage Compiler Rules (`forge.toolchain.watcom` & `forge.toolchain.evc3`)

For vintage targets with specialized proprietary toolchains, attach the native compilation rules (aliases: `forge.watcom`, `forge.evc3`, `watcom`, `evc3`):
```lua
target("my_retro_app")
    set_kind("binary")
    add_files("src/*.c")

    -- Open Watcom v2 C compiler & linker (DOS 32-bit & OS/2 Warp)
    if is_plat("dos", "os2") then
        add_rules("forge.toolchain.watcom", {override = true})
    -- Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
    elseif is_plat("wince") then
        add_rules("forge.toolchain.evc3", {override = true})
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

Forge treats a Lua module as an xmake package. There is no rockspec. Including Forge registers the local repository `forge-lua`. A recipe in `repository/packages` is an ordinary xmake project: metadata, then a `target` with `forge.lua.module`. `require` finds it through `LUA_PATH` and `LUA_CPATH`.

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

`repository/packages/f/forge-hello/xmake.lua` is the recipe:

```lua
set_kind("library", {headeronly = true})
set_homepage("https://github.com/projectum-lunare/forge")
set_description("Example pure Lua module installed by Forge")
set_license("MPL-2.0")

target("forge.hello")
    add_rules("forge.lua.module")
    add_files("src/hello.lua")
```

`forge.lua.module` installs the file where `require` looks. `set_kind("library", {headeronly = true})` tells xmake there is no C library. A C module adds `add_deps("lua")` and lists its `.c` file on the target. A tarball that has no xmake project, such as LPeg, is the case that receives a generated `xmake.lua` at install time.

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

`repository/packages/f/forge-hello` and `forge-native` are the reference recipes. LPeg has no xmake project, so its recipe writes one at install time. A new recipe lives at `packages/<initial>/<name>/xmake.lua`. Another recipe tree is registered with `add_repositories("my-lua /path/to/repo")`.

#### Multi-Runtime Orchestration (`@addon.forge.lua.runtime`)

Recipes in package repositories or downstream consumer projects can declare multi-runtime compatibility and version constraints with clean, boilerplate-free syntax:

```lua
package("my-extension")
    on_load(function (package)
        import("@addon.forge.lua.runtime").setup(package, {
            runtime = {"lua", "luajit"},
            version = ">=5.1 <=5.3",
        })
    end)

    on_install(function (package)
        io.writefile("xmake.lua", [[
            target("my_extension")
                add_rules("forge.lua.module")
                add_files("src/*.c")
        ]])
        import("@addon.forge.lua.module").install_project(package)
    end)
```

- **Seamless ABI Separation:** Dynamically registers runtime configurations to calculate distinct `buildhash` cache keys, preventing collisions between PUC-Lua and LuaJIT artifacts.
- **Targeted Runtimes:** Supports `lua` (PUC-Lua), `luajit`, and `openresty-luajit`. Mono-runtime packages can declare `runtime = "luajit"` directly.

### 7. LÖVE 2D Game Engine Integration (`forge.engine.love`)

Forge provides first-class support for developing and distributing 2D games with the [LÖVE (Love2D)](https://love2d.org) engine (aliases: `forge.love`, `forge.love.game`, `forge.lua.love`):

```lua
add_rules("mode.release", "mode.debug")

target("my_game")
    add_rules("forge.engine.love")

    -- Add native C modules from xmake-repo; automatically discovered & preloaded!
    add_packages("lua-cjson", "lpeg")

    -- Game sources and assets
    add_files("src/**.lua")
    add_files("assets/**")
```

#### Key Capabilities:
- **Dynamic C Extension Preloading:** Automatically inspects package manifests (`share/forge/lua-modules.lua`) across target dependencies to register each native library into `package.preload` in a generated C++ launcher. No hardcoded module tables and no manual C++ boilerplate required.
- **Fast Development Cycle (`xmake run`):** In debug/development mode, executes the game directly from `src/` with instant iteration.
- **Standalone Fused Binary (`xmake -m release`):** Automatically packages Lua files and assets into a ZIP bundle and fuses it directly to the executable binary. Produces a single, self-contained native executable (`my_game` / `my_game.exe`) with no separate `.love` archive required for the end user.
- **LuaJIT or PUC Lua Runtime:** Inherits the runtime configured in `packages/l/love` (`luajit` for maximum performance, or `lua 5.1` for PUC Lua compatibility).

#### Target Values & Configuration:
- `set_values("love.dir", "src")`: Explicit root directory containing `main.lua` (auto-detected by default).
- `set_values("love.fused", true|false)`: Force fused binary generation on or off (defaults to `true` in release mode, `false` in debug mode).
- `set_values("love.modules", {{name = "mymod", symbol = "luaopen_mymod"}})`: Manual registration for custom in-tree C modules.

### 8. Amulet Game Toolkit Integration (`forge.engine.amulet`)

Forge provides first-class support for creating and distributing audio/visual 2D/3D games with the [Amulet](http://www.amulet.xyz/) game toolkit (aliases: `forge.amulet`, `forge.amulet.game`, `forge.lua.amulet`):

```lua
add_rules("mode.release", "mode.debug")

target("my_game")
    add_rules("forge.engine.amulet")

    -- Add native C modules; automatically preloaded into package.preload!
    add_packages("lua-cjson", "lpeg")

    -- Game sources and assets
    add_files("src/**.lua")
    add_files("assets/**")
```

#### Key Capabilities:
- **Engine Initialization Hook:** Links against `libamulet.a` and automatically injects an engine hook (`am_set_custom_init_hook`) that registers all native C extension libraries (`luaopen_*`) into `package.preload` upon startup.
- **Fast Development Cycle (`xmake run`):** In debug mode, runs `main.lua` directly from the source tree with instant iteration and zero repacking delay.
- **Standalone Distribution Bundle (`xmake -m release`):** Packages all game scripts, assets, and dependency modules into an optimized `data.pak` archive placed beside the standalone game executable.
- **Dual Package Support:** Uses the enhanced `amulet` package in `projectum-lunare/xmake-repo` providing both static library linkage (`libamulet.a`), headers, and standalone CLI tool.

#### Target Values & Configuration:
- `set_values("amulet.dir", "src")`: Explicit root directory containing `main.lua` (auto-detected by default).
- `set_values("amulet.fused", true|false)`: Force `data.pak` packaging on or off (defaults to `true` in release mode, `false` in debug mode).
- `set_values("amulet.modules", {{name = "mymod", symbol = "luaopen_mymod"}})`: Manual registration for custom in-tree C modules.

### 9. Teal Typed Lua Integration (`forge.lang.teal`)

Forge provides first-class support for the [Teal](https://github.com/teal-language/tl) statically typed dialect of Lua (aliases: `forge.teal`, `forge.lua.teal`, `teal`):

```lua
target("my_typed_lib")
    add_rules("forge.lua.module", "forge.lang.teal")
    add_files("src/**.tl")
```

#### Key Capabilities:
- **Automatic Extension Binding (`.tl`):** Seamlessly recognizes `.tl` source files alongside `.lua` in modules and applications.
- **Strict Static Type Checking:** Verifies types at compile time via `tl gen -c`, catching errors early in the build graph before runtime.
- **Transpilation Pipeline:** Compiles typed Teal definitions into clean, standard Lua files placed in `build/lua/` and installed canonically into `share/lua/` and `lib/`.
- **Target Options:**
  - `set_values("forge.teal.check", false)`: Disable strict type validation if needed.
  - `set_values("forge.teal.outdir", "custom/dir")`: Explicit custom destination for transpiled Lua code.

### 10. Nelua Systems Language Integration (`forge.lang.nelua`)

Forge provides first-class integration for [Nelua](https://nelua.io/) (aliases: `forge.nelua`, `nelua`), a statically typed, meta-programmable systems programming language heavily inspired by Lua that compiles to C and WebAssembly:

```lua
target("my_systems_app")
    add_rules("forge.lang.nelua")
    add_files("src/*.nelua")
```

#### Key Capabilities:
- **Direct Object Compilation via ANSI/C99:** Compiles `.nelua` source files into intermediate C code, and passes them straight into the target platform's C compiler (GCC, Clang, MSVC, Open Watcom, or eVC3). Enables running Nelua on modern desktop/server systems as well as vintage architectures (DOS, WinCE, Amiga).
- **Dual Backend Support (C & Lua):** Supports compiling to native binaries/libraries or emitting clean Lua code:
  ```lua
  target("my_nelua_to_lua")
      add_rules("forge.lang.nelua")
      set_values("forge.nelua.generator", "lua")
      add_files("src/*.nelua")
  ```
- **Target Options & Flags:**
  - `set_values("forge.nelua.generator", "c"|"lua")`: Backend generator to use (defaults to `"c"`).
  - `set_values("forge.nelua.maximum_performance", true)`: Enable `-M` maximum performance optimizations.
  - `set_values("forge.nelua.defines", {"MY_DEF=1"})`: Pass custom `-D` preprocessor definitions.
  - `set_values("forge.nelua.pragmas", {"nogc"})`: Set initial Nelua compiler pragmas (`-P`).

### 11. Compile-to-Lua Transpilers (`forge.lang.*`)

Forge provides first-class, seamless Ahead-of-Time (AOT) transpilation for the most popular compile-to-Lua languages. You can mix and match them inside standard Lua apps, modules, LÖVE 2D games, or Amulet projects:

#### Fennel Lisp (`forge.lang.fennel`)
Compile [Fennel](https://fennel-lang.org) Lisp (`.fnl`) into clean Lua (aliases: `forge.fennel`, `fennel`):
```lua
target("my_fennel_game")
    add_rules("forge.engine.love", "forge.lang.fennel")
    add_files("src/**.fnl")
    set_values("forge.fennel.correlate", true) -- match source line numbers
```

#### MoonScript (`forge.lang.moonscript`)
Compile [MoonScript](https://moonscript.org) (`.moon`) CoffeeScript-style syntax into Lua (aliases: `forge.moonscript`, `moonscript`):
```lua
target("my_moon_module")
    add_rules("forge.lua.module", "forge.lang.moonscript")
    add_files("src/**.moon")
```

#### YueScript (`forge.lang.yuescript`)
Compile [YueScript](https://yuescript.org) (`.yue`), the high-performance C++-powered evolution of MoonScript (aliases: `forge.yuescript`, `yuescript`):
```lua
target("my_yue_app")
    add_rules("forge.lua.app", "forge.lang.yuescript")
    add_files("src/**.yue")
    set_values("forge.yuescript.target", "5.1") -- target Lua 5.1/LuaJIT ABI
```

---

## CLI Usage

### Check SDK Status & Toolchain Matrix
```bash
xmake forge list
```

### Interactive REPL (`xmake forge repl`)
Launch an interactive Lua REPL with the project's exact environment, compiled C extensions, and package dependencies automatically resolved in `LUA_PATH` and `LUA_CPATH`:
```bash
# Default runtime (PUC-Lua)
xmake forge repl

# Run with LuaJIT
xmake forge -r luajit repl

# Evaluate an expression directly within the project environment and exit
xmake forge --eval="local m = require('mymodule'); print(m.hello())" repl
```

### Instant Project Scaffolding (`xmake forge create`)
Quickly instantiate new idiomatic projects from built-in templates:
```bash
# Create a runnable Lua app (with binary launcher)
xmake forge create myapp -t app

# Create a reusable pure Lua module
xmake forge create mymod -t module

# Create a native C extension (.so/.dll) compatible across Lua 5.1-5.4 & LuaJIT
xmake forge create mynative -t cmodule

# Create a LÖVE 2D game
xmake forge create mygame -t love

# Create a LÖVE 2D game with Lua 5.3 compatibility layer (utf8, table/string pack)
xmake forge create mygame -t love-compat

# Create an Amulet 2D/3D game
xmake forge create myamulet -t amulet

# Create an Amulet 2D/3D game with Lua 5.3 compatibility layer (utf8, table/string pack)
xmake forge create myamulet -t amulet-compat
```
*Tip: Standard Xmake creation syntax is also fully supported, e.g. `xmake create -l lua -t cmodule mynative`.*

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
