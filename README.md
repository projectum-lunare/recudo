# Projectum Lunare Recudo

> **Lua, where Lua rarely goes.**  
> Build, cross-compile and ship Lua for machines that never met it — Amiga, Atari ST, DOS, OS/2, Windows CE, KolibriOS — and keep the same project running on modern BSDs and Linux.

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)
[![Build System: Xmake](https://img.shields.io/badge/Build%20System-Xmake-red.svg)](https://xmake.io)

---

> *"Theatrum meum recudo; eius media pars recusa ante annum fuit."*  
> *"I am re-striking my Theatrum; its middle section was re-struck before this year."*  
> — Abraham Ortelius, on re-engraving the plates of the first modern atlas — Antwerp, 2 May 1591

---

## Why Recudo

When retro computing comes up, you think C and assembly. Rarely Lua. Yet Lua is small, written in ISO C, fits in a few hundred kilobytes, and asks almost nothing of the host — exactly the qualities vintage machines reward. What is missing is not the interpreter: it is everything around it. Packaging, linking, launcher scripts, bundling, version pinning — all of it is hand-rolled, per machine, every time.

**Recudo** closes that gap. It is the build infrastructure and Lua delivery pipeline of **Projectum Lunare** (powering [`solo`](https://github.com/projectum-lunare/solo), [`dotstar`](https://github.com/projectum-lunare/dotstar), and other systems), implemented as a native [Xmake](https://xmake.io) addon. Instead of reinventing low-level DAG build graphs, one `xmake.lua` drives the C toolchain and the Lua pipeline side by side:

- **One source, many dies.** The same module becomes a `.so` on Linux, a static archive on Amiga, and a fused single-binary on release — struck through each toolchain like a coin through its die.
- **A complete Lua pipeline** — modules, native C extensions, app launchers, monolithic bundles, isolated environments — a LuaRocks alternative that lives inside the build graph.
- **Vintage toolchains as first-class citizens** — Open Watcom v2, MS eVC 3.0, Bebbo GCC, FreeMiNT GCC, Kos32 GCC — executed as native Xmake rules, with no brittle shell or Python wrapper scripts.
- **Formal custom platforms** — `amiga`, `atari`, `kolibri`, `dos`, `os2`, `wince`, plus first-class `freebsd`, `openbsd`, `netbsd` and `dragonflybsd`.
- **Beyond plain Lua** — LÖVE 2D and Amulet game packaging, Teal static typing, Nelua systems code, Haxe multi-backend compilation, and Fennel/MoonScript/YueScript transpilers, all flowing through the same pipeline.
- **Matrix orchestration** — `xmake recudo` to audit, cross-compile and benchmark across every target.

*recudo* — Latin, *recudere*: *to strike anew; to re-forge; to re-mint*. The name is the job, twice over: re-striking one source through every die in the matrix — and re-forging the Lua ecosystem itself, where rockspecs give way to ordinary xmake recipes, folders of scripts give way to single executables, and the map of destinations grows to machines the ecosystem never shipped to.

---

## Installation

Install Recudo directly via Xmake:
```bash
xmake addon --install github:projectum-lunare/recudo
```

---

## Sixty Seconds: Lua on a 68020

One project, one `xmake.lua`, a native C module and a pure Lua app — built for the host and for two vintage machines:

```lua
add_addons("recudo")
includes("@addon/recudo/recudo.lua")

target("hello.native")
    add_rules("recudo.lua.module")   -- shared .so/.dll on desktop, static archive on vintage
    add_files("src/native/*.c")

target("hello")
    add_rules("recudo.lua.app")      -- portable launcher in build/bin
    set_values("recudo.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_deps("hello.native")
```

```bash
xmake recudo posix   # host build (system GCC/Clang)    → build/posix
xmake recudo amiga   # Bebbo GCC, m68k-amigaos-gcc      → build/amiga
xmake recudo dos     # Open Watcom v2, owcc -b dos32a   → build/dos
```

Iterate on the host with `xmake run hello`, then strike the same source through each die. When release day comes, `recudo.lua.bundle` fuses runtime, scripts and native modules into a single self-contained executable. The sections below unpack every step.

---

## The Lua Pipeline

Recudo provides a first-class build and execution system for Lua 5.4+ projects without requiring external package managers:

### 1. Pure Lua Module (`recudo.lua.module`)
Automatically stages and packages `.lua` source files into `build/lua/` with canonical paths:
```lua
target("mylib")
    add_rules("recudo.lua.module")
    add_files("src/**.lua")
```

### 2. Native C & Hybrid Modules
Compiles C code into Lua-loadable shared modules (`.so` / `.dll`) on modern OSes or static archives on vintage platforms. The linkage mode can be automatic or explicitly specified:
```lua
-- Shared module (default on desktop: Linux, macOS, Windows)
target("mylib.native")
    add_rules("recudo.lua.module")
    add_files("src/native/*.c")

-- Static module (default on vintage targets, or forced for static embedding)
target("mylib.static")
    set_kind("static") -- or: set_values("recudo.lua.kind", "static")
    add_rules("recudo.lua.module")
    add_files("src/native/*.c")
```

This is where the vintage story stops being a promise: Amiga, Atari, KolibriOS, DOS, OS/2, Windows CE and Wasm cannot `dlopen`, so the module ships as a plain archive and links straight into the final binary — native C extensions work everywhere, not only where dynamic loading exists.

### 3. Application Launcher (`recudo.lua.app`)
Generates standalone portable shell (`sh`) / batch (`cmd`) launchers in `build/bin/<app>` and supports instant execution via `xmake run`:
```lua
target("my_app")
    add_rules("recudo.lua.app")
    set_values("recudo.lua.entry", "src/main.lua")
    add_deps("mylib", "mylib.native")
```

Run directly:
```bash
xmake run my_app --help
./build/bin/my_app --help
```

### 4. Monolithic Standalone Bundler (`recudo.lua.bundle`)
Embeds Lua runtime and compiles all Lua scripts directly into ANSI C byte arrays via an ERB-style template engine, generating a single self-contained native executable with zero external dependencies:
```lua
target("my_standalone_app")
    add_rules("recudo.lua.bundle")
    add_files("src/**.lua")
    set_values("recudo.lua.entry", "src/main.lua")

    -- Optional: supply a custom C template for specialized runtimes (e.g., SDL, Watcom GUI)
    -- set_values("recudo.lua.template", "src/custom_main.c.in")
```

### 5. Environment & IDE Integration (`xmake recudo env`)
Export project-local `LUA_PATH` and `LUA_CPATH` without global pollution:
```bash
# Set environment in current shell session (like luarocks path)
eval $(xmake recudo env)

# Export .env file for VS Code, Neovim & LuaLS (Language Server)
xmake recudo env --export-env
```

### 6. Lua modules as xmake packages

Recudo treats a Lua module as an xmake package. There is no rockspec. Including Recudo registers the local repository `recudo-lua`. A recipe in `repository/packages` is an ordinary xmake project: metadata, then a `target` with `recudo.lua.module`. `require` finds it through `LUA_PATH` and `LUA_CPATH`.

#### Pure Lua (`.lua` only)

A project made only of `.lua` files does not compile C and does not require the `lua` package. `xmake run` uses a Lua `>= 5.4` interpreter from `PATH` or `LUA_BIN`. Dependencies are pure Lua recipes such as `recudo-hello`:

```lua
add_requires("recudo-hello")

target("app")
    add_rules("recudo.lua.app")
    set_values("recudo.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("recudo-hello")
```

`repository/packages/r/recudo-hello/xmake.lua` is the recipe:

```lua
set_kind("library", {headeronly = true})
set_homepage("https://github.com/projectum-lunare/recudo")
set_description("Example pure Lua module installed by Recudo")
set_license("MPL-2.0")

target("recudo.hello")
    add_rules("recudo.lua.module")
    add_files("src/hello.lua")
```

`recudo.lua.module` installs the file where `require` looks. `set_kind("library", {headeronly = true})` tells xmake there is no C library. A C module adds `add_deps("lua")` and lists its `.c` file on the target. A tarball that has no xmake project, such as LPeg, is the case that receives a generated `xmake.lua` at install time.

`recudo.lua.bundle` is the step that leaves pure Lua: it generates a C executable, so that target needs the `lua` package even when every script is `.lua`.

#### Pure Lua project, C recipe

The project stays `.lua` only. The link mode is the project's:

```bash
xmake f --kind=shared   # dynamic: shared liblua and .so/.dll
xmake f --kind=static   # static: archives only, the default
```

That choice applies to the targets and to every package dependency. Amiga, Atari, KolibriOS, DOS, OS/2, Windows CE and Wasm stay static even with `--kind=shared`, because they cannot `dlopen`.

In dynamic mode the recipe records the Lua package directory. `xmake run` copies the interpreter, `liblua` and the modules into `build/bin/<app>.runtime`. `bin/lua` puts `../lib` on the loader path. `LUA_PATH` and `LUA_CPATH` do not fall through to the system tree. Copy `build/bin/<app>` together with `build/bin/<app>.runtime`.

```lua
add_requires("recudo-native")

target("app")
    add_rules("recudo.lua.app")
    set_values("recudo.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("recudo-native")
```

In static mode there is no `.so`. `recudo.lua.bundle` links the static `luaopen_*` and `liblua.a` into one executable.

#### Native modules

A C module follows the same `--kind`. Shared mode installs `.so` or `.dll`. Static mode installs only the archive and `recudo.lua.bundle` links `luaopen_*`. Amiga, Atari, KolibriOS, DOS, OS/2, Windows CE and Wasm install the archive in either mode.

```lua
add_requires("lua", {system = false})
add_requires("recudo-hello", "recudo-native")

target("app")
    add_rules("recudo.lua.app")
    set_values("recudo.lua.entry", "src/main.lua")
    add_files("src/main.lua")
    add_packages("lua", "recudo-hello", "recudo-native")
```

`repository/packages/r/recudo-hello` and `recudo-native` are the reference recipes. LPeg has no xmake project, so its recipe writes one at install time. A new recipe lives at `packages/<initial>/<name>/xmake.lua`. Another recipe tree is registered with `add_repositories("my-lua /path/to/repo")`.

#### Multi-Runtime Orchestration (`@addon.recudo.lua.runtime`)

Recipes in package repositories or downstream consumer projects can declare multi-runtime compatibility and version constraints with clean, boilerplate-free syntax:

```lua
package("my-extension")
    on_load(function (package)
        import("@addon.recudo.lua.runtime").setup(package, {
            runtime = {"lua", "luajit"},
            version = ">=5.1 <=5.3",
        })
    end)

    on_install(function (package)
        io.writefile("xmake.lua", [[
            target("my_extension")
                add_rules("recudo.lua.module")
                add_files("src/*.c")
        ]])
        import("@addon.recudo.lua.module").install_project(package)
    end)
```

- **Seamless ABI Separation:** Dynamically registers runtime configurations to calculate distinct `buildhash` cache keys, preventing collisions between PUC-Lua and LuaJIT artifacts.
- **Targeted Runtimes:** Supports `lua` (PUC-Lua), `luajit`, and `openresty-luajit`. Mono-runtime packages can declare `runtime = "luajit"` directly.

---

## Game Engines

### 7. LÖVE 2D Game Engine Integration (`recudo.engine.love`)

Recudo provides first-class support for developing and distributing 2D games with the [LÖVE (Love2D)](https://love2d.org) engine:

```lua
add_rules("mode.release", "mode.debug")

target("my_game")
    add_rules("recudo.engine.love")

    -- Add native C modules from xmake-repo; automatically discovered & preloaded!
    add_packages("lua-cjson", "lpeg")

    -- Game sources and assets
    add_files("src/**.lua")
    add_files("assets/**")
```

#### Key Capabilities:
- **Dynamic C Extension Preloading:** Automatically inspects package manifests (`share/recudo/lua-modules.lua`) across target dependencies to register each native library into `package.preload` in a generated C++ launcher. No hardcoded module tables and no manual C++ boilerplate required.
- **Fast Development Cycle (`xmake run`):** In debug/development mode, executes the game directly from `src/` with instant iteration.
- **Standalone Fused Binary (`xmake -m release`):** Automatically packages Lua files and assets into a ZIP bundle and fuses it directly to the executable binary. Produces a single, self-contained native executable (`my_game` / `my_game.exe`) with no separate `.love` archive required for the end user.
- **LuaJIT or PUC Lua Runtime:** Inherits the runtime configured in `packages/l/love` (`luajit` for maximum performance, or `lua 5.1` for PUC Lua compatibility).

#### Target Values & Configuration:
- `set_values("recudo.engine.love.dir", "src")`: Explicit root directory containing `main.lua` (auto-detected by default).
- `set_values("recudo.engine.love.fused", true|false)`: Force fused binary generation on or off (defaults to `true` in release mode, `false` in debug mode).
- `set_values("recudo.engine.love.modules", {{name = "mymod", symbol = "luaopen_mymod"}})`: Manual registration for custom in-tree C modules.

### 8. Amulet Game Toolkit Integration (`recudo.engine.amulet`)

Recudo provides first-class support for creating and distributing audio/visual 2D/3D games with the [Amulet](http://www.amulet.xyz/) game toolkit:

```lua
add_rules("mode.release", "mode.debug")

target("my_game")
    add_rules("recudo.engine.amulet")

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
- `set_values("recudo.engine.amulet.dir", "src")`: Explicit root directory containing `main.lua` (auto-detected by default).
- `set_values("recudo.engine.amulet.fused", true|false)`: Force `data.pak` packaging on or off (defaults to `true` in release mode, `false` in debug mode).
- `set_values("recudo.engine.amulet.modules", {{name = "mymod", symbol = "luaopen_mymod"}})`: Manual registration for custom in-tree C modules.

---

## Language Dialects

### 9. Teal Typed Lua Integration (`recudo.lang.teal`)

Recudo provides first-class support for the [Teal](https://github.com/teal-language/tl) statically typed dialect of Lua:

```lua
target("my_typed_lib")
    add_rules("recudo.lua.module", "recudo.lang.teal")
    add_files("src/**.tl")
```

#### Key Capabilities:
- **Automatic Extension Binding (`.tl`):** Seamlessly recognizes `.tl` source files alongside `.lua` in modules and applications.
- **Strict Static Type Checking:** Verifies types at compile time via `tl gen -c`, catching errors early in the build graph before runtime.
- **Transpilation Pipeline:** Compiles typed Teal definitions into clean, standard Lua files placed in `build/lua/` and installed canonically into `share/lua/` and `lib/`.
- **Target Options:**
  - `set_values("recudo.lang.teal.check", false)`: Disable strict type validation if needed.
  - `set_values("recudo.lang.teal.outdir", "custom/dir")`: Explicit custom destination for transpiled Lua code.

### 10. Nelua Systems Language Integration (`recudo.lang.nelua`)

Recudo provides first-class integration for [Nelua](https://nelua.io/), a statically typed, meta-programmable systems programming language heavily inspired by Lua that compiles to C and WebAssembly:

```lua
target("my_systems_app")
    add_rules("recudo.lang.nelua")
    add_files("src/*.nelua")
```

#### Key Capabilities:
- **Direct Object Compilation via ANSI/C99:** Compiles `.nelua` source files into intermediate C code, and passes them straight into the target platform's C compiler (GCC, Clang, MSVC, Open Watcom, or eVC3). Enables running Nelua on modern desktop/server systems as well as vintage architectures (DOS, WinCE, Amiga).
- **Dual Backend Support (C & Lua):** Supports compiling to native binaries/libraries or emitting clean Lua code:
  ```lua
  target("my_nelua_to_lua")
      add_rules("recudo.lang.nelua")
      set_values("recudo.lang.nelua.generator", "lua")
      add_files("src/*.nelua")
  ```
- **Target Options & Flags:**
  - `set_values("recudo.lang.nelua.generator", "c"|"lua")`: Backend generator to use (defaults to `"c"`).
  - `set_values("recudo.lang.nelua.maximum_performance", true)`: Enable `-M` maximum performance optimizations.
  - `set_values("recudo.lang.nelua.defines", {"MY_DEF=1"})`: Pass custom `-D` preprocessor definitions.
  - `set_values("recudo.lang.nelua.pragmas", {"nogc"})`: Set initial Nelua compiler pragmas (`-P`).

### 11. Haxe Multi-Target Language Integration (`recudo.lang.haxe`)

Recudo provides first-class, multi-backend support for [Haxe](https://haxe.org/), a high-level, strictly-typed multi-target programming language:

```lua
-- Native C++ application compiled directly with Xmake's toolchains & linker
target("my_native_app")
    set_kind("binary")
    add_rules("recudo.lang.haxe")
    add_files("src/NativeMain.hx")
    set_values("recudo.lang.haxe.backend", "cpp")
    set_values("recudo.lang.haxe.main", "NativeMain")
    add_packages("haxe", "hxcpp")

-- Portable Lua application orchestrated through the Recudo Lua runtime
target("my_lua_app")
    add_rules("recudo.lua.app", "recudo.lang.haxe")
    add_files("src/LuaMain.hx")
    set_values("recudo.lang.haxe.main", "LuaMain")
    add_packages("haxe")
```

#### Key Capabilities:
- **Direct C++ Object Compilation via Xmake:** When targeting the C++ backend (`backend = "cpp"` or inferred for `binary`/`static` targets), Haxe emits intermediate C++ code with `-D no-compilation`. Xmake compiles every generated `.cpp` file with native toolchains, parallel job scheduler, and compiler flags, linking against the pre-compiled `hxcpp` runtime library.
- **Multi-Backend Output Support:** Supports targeting `cpp` (native executable or static library), `lua` (PUC-Lua 5.1-5.4 or LuaJIT), `js` (JavaScript), `python`, `hl` (HashLink), `jvm`, and `cs` (C#).
- **Automated Standard Library & haxelib Resolution:** Automatically provisions and points `HAXE_STD_PATH` to the bundled standard library and routes `haxelib` lookups without host dependencies.
- **Target Options & Flags:**
  - `set_values("recudo.lang.haxe.backend", "cpp"|"lua"|"js"|"python"|"hl"|"jvm"|"cs")`: Target backend (defaults to `"cpp"` for binary/static targets, `"lua"` for Lua apps/modules).
  - `set_values("recudo.lang.haxe.main", "MainClassName")`: Entry class name.
  - `set_values("recudo.lang.haxe.classpaths", {"src", "lib"})`: Add custom `-cp` search paths.
  - `set_values("recudo.lang.haxe.defines", {"my_flag", "key=val"})`: Add custom `-D` compiler definitions.
  - `set_values("recudo.lang.haxe.libs", {"simdjson"})`: Pass `-lib <name>` dependencies.
  - `set_values("recudo.lang.haxe.hxml", "build.hxml")`: Build from an existing `.hxml` specification file.
  - `set_values("recudo.lang.haxe.lua_version", "5.4"|"5.3"|"5.2"|"5.1")`: Specify target Lua version for Lua backend.

### 12. Compile-to-Lua Transpilers (`recudo.lang.*`)

Recudo provides first-class, seamless Ahead-of-Time (AOT) transpilation for the most popular compile-to-Lua languages. You can mix and match them inside standard Lua apps, modules, LÖVE 2D games, or Amulet projects:

#### Fennel Lisp (`recudo.lang.fennel`)
Compile [Fennel](https://fennel-lang.org) Lisp (`.fnl`) into clean Lua:
```lua
target("my_fennel_game")
    add_rules("recudo.engine.love", "recudo.lang.fennel")
    add_files("src/**.fnl")
    set_values("recudo.lang.fennel.correlate", true) -- match source line numbers
```

#### MoonScript (`recudo.lang.moonscript`)
Compile [MoonScript](https://moonscript.org) (`.moon`) CoffeeScript-style syntax into Lua:
```lua
target("my_moon_module")
    add_rules("recudo.lua.module", "recudo.lang.moonscript")
    add_files("src/**.moon")
```

#### YueScript (`recudo.lang.yuescript`)
Compile [YueScript](https://yuescript.org) (`.yue`), the high-performance C++-powered evolution of MoonScript:
```lua
target("my_yue_app")
    add_rules("recudo.lua.app", "recudo.lang.yuescript")
    add_files("src/**.yue")
    set_values("recudo.lang.yuescript.target", "5.1") -- target Lua 5.1/LuaJIT ABI
```

---

## Toolchains & Platforms: The Dies

The pipeline above needs somewhere to strike. Recudo declares formal platforms and wires the compiler matrix, so choosing a target is one word on the command line.

### Supported Platforms & Toolchains

| Platform            | Target OS           | Default Arch         | Supported Architectures (Xmake Normalized)                                                                         | Toolchain   | Toolset / Compiler                              | SDK Fallback                 |
| :------------------ | :------------------ | :------------------- | :----------------------------------------------------------------------------------------------------------------- | :---------- | :---------------------------------------------- | :--------------------------- |
| **`amiga`**         | AmigaOS Classic     | `m68k`               | `m68k`                                                                                                             | `amigaos`   | Bebbo GCC (`m68k-amigaos-gcc`)                  | `~/.local/opt/amigaos-gcc`   |
| **`atari`**         | Atari ST / FreeMiNT | `m68k`               | `m68k`                                                                                                             | `atarist`   | MiNT ELF GCC 13 (`m68k-atari-mintelf-gcc`; classic mint via `ATARIST_SDK`) | `~/.local/opt/atarist-mintelf` |
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

Standard Xmake merges all BSD distributions into a single generic `bsd` platform. Recudo separates them into first-class targets (`freebsd`, `openbsd`, `netbsd`, and `dragonflybsd`) while normalizing official upstream architecture names into canonical Xmake identifiers:

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

### Atari Rule (`recudo.toolchain.atarist`)

Two real toolchains exist for the Atari ST, and both are installable:

| Variant | Compiler | Objects | Symbols | Debugger |
| :--- | :--- | :--- | :--- | :--- |
| `mintelf` (default) | GCC 13.3.0 | ELF | no underscore | GDB |
| `mint` | GCC 4.6.4 | a.out | leading underscore | MonST2 |

The rule selects the variant per target, so legacy and modern code can live in
one project:

```lua
target("modern")
    add_rules("recudo.toolchain.atarist")                    -- mintelf

target("legacy")
    add_rules("recudo.toolchain.atarist")
    set_values("recudo.toolchain.atarist.variant", "mint")   -- classic
    set_values("recudo.toolchain.atarist.cpu", "68020")      -- default: 68000
```

Install whichever you need: `xmake recudo tool install atarist-mintelf` and/or
`xmake recudo tool install atarist-mint`. The classic variant links with
`-Wl,--traditional-format` so MonST2 and other period debuggers can read the
symbols.

### vbcc Rule (`recudo.toolchain.vbcc`)

[vbcc](http://www.compilers.de/vbcc.html) is a portable ISO C compiler whose one
driver covers every backend it ships, selected per target with a `+name` flag.
It is the alternative to the GCC toolchains for AmigaOS and Atari, and the only
compiler Recudo has for the 8-bit targets:

```lua
target("hello_c64")
    add_rules("recudo.toolchain.vbcc")
    set_values("recudo.toolchain.vbcc.target", "c64")   -- default: aos68k
    add_files("src/*.c")
```

| `target` value | Output |
| :--- | :--- |
| `c64`, `c128`, `pet`, `x16`, `m65` | Commodore 8-bit program |
| `nes` | NES ROM (iNES) |
| `atari` | Atari 8-bit program |
| `bbc` | BBC Micro program |
| `aos68k`, `kick13` | AmigaOS loadseg()ble executable |
| `tos`, `mint` | Atari ST executable |
| `jaguar` | Atari Jaguar executable |
| `aosppc`, `morphos`, `warpos` | PowerPC Amiga executable |

Install it first with `xmake recudo tool install vbcc`. vbcc produces far
smaller binaries than GCC because its libc is minimal: a bare `main()` is
252 bytes for the C64 and 1.2 KB for AmigaOS, against ~130 KB from a GCC
toolchain.

### Vintage Compiler Rules (`recudo.toolchain.watcom` & `recudo.toolchain.evc3`)

For vintage targets with specialized proprietary toolchains, attach the native compilation rules:
```lua
target("my_retro_app")
    set_kind("binary")
    add_files("src/*.c")

    -- Open Watcom v2 C compiler & linker (DOS 32-bit & OS/2 Warp)
    if is_plat("dos", "os2") then
        add_rules("recudo.toolchain.watcom", {override = true})
    -- Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
    elseif is_plat("wince") then
        add_rules("recudo.toolchain.evc3", {override = true})
        -- For console apps using standard main() instead of GUI WinMain():
        -- set_values("recudo.toolchain.evc3.entry", "mainACRTStartup")
    end
```
*(Standard platforms like `amiga`, `atari`, `kolibri`, `freebsd`, `openbsd`, `netbsd`, `dragonflybsd`, and `linux` use native GCC/Clang toolchains automatically with standard Xmake C/C++ build graphs).*

> [!NOTE]
> **Windows CE Entry Point:** By default, executables built with `recudo.toolchain.evc3` target the CE graphical subsystem and use `/entry:WinMainCRTStartup` (which invokes `WinMain`). If you are compiling a console / CLI application with a standard `main()`, set the entry point to `mainACRTStartup`:
> ```lua
> set_values("recudo.toolchain.evc3.entry", "mainACRTStartup")
> -- or: add_ldflags("/entry:mainACRTStartup")
> ```

### Provisioning SDKs (`xmake recudo tool`)

SDKs are provisioned as pure data: every tool is a declarative spec (sources
pinned by sha256, editions, env map, smoke test) ported from dotstar's
toolchain orchestrator. Provisioning lands exactly where detection looks
(`~/.local/opt/<sdk>` on Unix, `%APPDATA%\<sdk>` on Windows), so
`xmake recudo list` flips from `✗ Miss` to `✓ Ready` without manual steps:

```bash
xmake recudo tool list                      # registered tools and install status
xmake recudo tool install amigaos-gcc       # download, verify sha256, extract, probe
xmake recudo tool install --all             # provision every registered tool
xmake recudo tool test watcom               # smoke test (compiler banners, -dumpversion...)
xmake recudo tool test --all
xmake recudo tool info evc3                 # editions, binaries and paths
xmake recudo tool which amigaos-sdk m68k-amigaos-gcc
```

`evc3` requires an edition (`--edition=arm|mips|sh3|sh4|x86|ppc`) and pulls its
runner dependency (`wibo`) automatically; the eVC 3.0 media comes from the
Internet Archive and the ISO trees are lowercased on extraction so Unix
toolchains and `#include` directives resolve. `install --all` followed by
`test --all` is also the CI recipe for validating the matrix against real SDKs.

### Cross-Platform SDK Detection

Automatic resolution across Unix (`~/.local/opt/<sdk>`) and Windows (`%APPDATA%`, `%LOCALAPPDATA%`). Run `xmake recudo list` at any time to audit the whole matrix.

---

## CLI Usage

### Check SDK Status & Toolchain Matrix
```bash
xmake recudo list
```

### Interactive REPL (`xmake recudo repl`)
Launch an interactive Lua REPL with the project's exact environment, compiled C extensions, and package dependencies automatically resolved in `LUA_PATH` and `LUA_CPATH`:
```bash
# Default runtime (PUC-Lua)
xmake recudo repl

# Run with LuaJIT
xmake recudo -r luajit repl

# Evaluate an expression directly within the project environment and exit
xmake recudo --eval="local m = require('mymodule'); print(m.hello())" repl
```

### Instant Project Scaffolding (`xmake recudo create`)
Quickly instantiate new idiomatic projects from built-in templates:
```bash
# Create a runnable Lua app (with binary launcher)
xmake recudo create myapp -t app

# Create a reusable pure Lua module
xmake recudo create mymod -t module

# Create a native C extension (.so/.dll) compatible across Lua 5.1-5.4 & LuaJIT
xmake recudo create mynative -t cmodule

# Create a LÖVE 2D game
xmake recudo create mygame -t love

# Create a LÖVE 2D game with Lua 5.3 compatibility layer (utf8, table/string pack)
xmake recudo create mygame -t love-compat

# Create an Amulet 2D/3D game
xmake recudo create myamulet -t amulet

# Create an Amulet 2D/3D game with Lua 5.3 compatibility layer (utf8, table/string pack)
xmake recudo create myamulet -t amulet-compat
```
*Tip: Standard Xmake creation syntax is also fully supported, e.g. `xmake create -l lua -t cmodule mynative`.*

### Build for a Specific Target
Target builds are isolated by default into `build/<target>` (e.g. `build/dos`, `build/amiga`), preserving independent configurations and artifacts:
```bash
xmake recudo amiga
xmake recudo atari
xmake recudo kolibri
xmake recudo dos
xmake recudo os2
xmake recudo wince
xmake recudo freebsd
xmake recudo posix

# To disable build directory isolation and build into root build/:
xmake recudo dos --no-isolate
```

### Run Full Multi-Platform Matrix Build
```bash
xmake recudo all
```

---

## License

Mozilla Public License Version 2.0 (MPL-2.0). See [LICENSE](LICENSE) for details.
