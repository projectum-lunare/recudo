# Recudo — Roadmap & Open Items

Things that are known, decided, and not yet built. Each entry says what it is,
why it matters, and what "done" looks like, so it can be picked up cold.

---

## Toolchains

### AmigaOS 4 SDK (PowerPC)

**Status:** partially covered by `vbcc`.

`vbcc +aosppc` already produces valid AmigaOS 4 binaries — ELF 32-bit
big-endian PowerPC — and it ships a minimal libc for the target
(`targets/ppc-amigaos/`, 1.2 MB of headers and libraries). What it does **not**
ship are the AmigaOS 4 API headers: Intuition, exec, graphics, MUI, AmiSSL and
the rest of the system SDK.

Two paths, in increasing order of cost:

1. **Declare the platform against vbcc** (cheap, ~1 hour)
   Add `id = "amigaos4"` to `modules/catalog.lua` with `arch = "ppc"`,
   `probe = "vbcc"` and `vbcc_target = "aosppc"`. Projects that are pure C or
   bring their own headers build immediately through the existing
   `recudo.toolchain.vbcc` rule. Document that system APIs need the SDK.

2. **Bundle the official SDK + a modern GCC** (expensive, ~half a day)
   The Hyperion SDK (`SDK_54.25.lha`, 346 MB) is the only official source and
   it is an Amiga `.lha` archive. There is **no standalone cross-compiler
   tarball** for AmigaOS 4 anywhere: the working toolchains ship as Docker
   images — [`walkero/amigagccondocker`](https://github.com/walkero-gr/AmigaGCConDocker)
   (`os4-gcc13`, GCC 13.4.0 + SDK 54.25 + MUI + AmiSSL) and
   [`sacredbanana/AmigaSDK-gcc`](https://github.com/sacredbanana/AmigaSDK-gcc).
   Following the `evc3` precedent: pull the image once, export
   `/opt/ppc-amigaos`, package it reproducibly, host it on the project's
   archive.org account, and write an `amigaos4-gcc` package recipe against it.
   Expect a bundle in the 200-400 MB range.

**Done when:** `xmake recudo amigaos4` builds a program that calls at least one
AmigaOS 4 API (e.g. `IDOS->Printf`) and the binary runs under an emulator
(QEMU Sam460ex or AmigaForever).

### vbcc on Windows and macOS hosts

**Status:** the `vbcc` recipe installs on Linux only.

vbcc ships one binary distribution per host, and only the Linux one is wired up:

| Host | Upstream artifact | Size | State |
| :--- | :--- | :--- | :--- |
| Linux x86_64 | `vbcc_linux_x64.tar.gz` | 30.5 MB | installed and validated |
| Linux arm | `vbcc_linux_arm.tar.gz` | — | available, not tested |
| **Windows x64** | `vbcc_win_x64.zip` | **16.5 MB** | **not packaged** |
| macOS | none published | — | see below |

The same driver, the same 65 targets, the same `VBCC` environment variable —
the only difference is the archive format (`.zip` instead of `.tar.gz`) and the
binary suffix (`vc.exe`). The recipe needs:

- a host branch in the URL selection, like `wibo` does with its per-host assets
  (`os.host() == "windows"` -> the zip, sha256 pinned after a download);
- `unzip`-style extraction — `utils.archive` handles zip, so `tree.descend` plus
  `tree.copy_tree` already cover it;
- `vc.exe` / `vbccm68k.exe` in the `on_test` smoke build (the
  `run_capture` helper passes arguments through unchanged, so a `.exe` suffix is
  the only edit);
- `make_executable` is a no-op on Windows, which is correct — the zip carries
  usable binaries.

**macOS:** upstream publishes no macOS binary distribution, only the Windows and
Linux ones. Options are to run the Linux build under Rosetta (it is a
statically linked x86_64 binary, and Rosetta 2 handles those), or to build vbcc
from source — the project ships sources and build scripts. Rosetta is the cheap
path and mirrors what the `wibo` recipe already does for its Mach-O asset.

**Done when:** `xmake recudo tool install vbcc` succeeds on Windows and the
`c64` smoke build produces a `.prg` from a native `vc.exe`.

### AROS

**Status:** not started.

AROS has **no published cross-compiler SDK** — the documented path is to build
it. From [`deadwood2/AROS`](https://github.com/deadwood2/AROS), branch
`alt-abiv0`: `./rebuild.sh` option `1) toolchain-alt-abiv0-i386`, then
`3) alt-abiv0-linux-i386`. The compiler lands in
`toolchain-alt-abiv0-i386/i386-aros-gcc` and needs `--sysroot` pointing at the
built AROS `Development` tree. There is also `core-x86_64` for the 64-bit ABI.

An older prebuilt `i386-all-sdk` (a self-installing SDK) exists on the AROS
developer pages but its download links are dead.

Cost: a full AROS source build (long) or a one-time bundle of the resulting
toolchain + sysroot, following the `evc3` precedent. ABIv0 (i386) and the newer
core (x86_64) are different ABIs and would be separate packages.

**Done when:** `xmake recudo aros` builds a binary that runs under the hosted
AROS (`AROSBootstrap`).

### Plan 9 / 9front

**Status:** not started; toolchain identified.

Plan 9 uses its own C dialect and object format, so GCC and Clang are out.
[`aryx/goken9cc`](https://github.com/aryx/goken9cc) is the maintained fork of
Ken Thompson's `kencc`: it builds on Linux/macOS/Windows with a normal C
compiler, then cross-compiles to Plan 9. Architecture is chosen by the
one-letter prefix — `8c/8a/8l` for 386, `6c/6a/6l` for amd64, `5c/5a/5l` for
ARM, `2c/2a/2l` for m68k, plus riscv, mips, sparc, powerpc, alpha.
[`michaelengel/kencc-cross`](https://github.com/michaelengel/kencc-cross) is an
alternative with prebuilt binaries for older hosts.

The build is `./configure && ./scripts/build-mk.sh && ./scripts/promote-mk.sh &&
. env.sh && mk && mk install`, which needs a host C compiler only to bootstrap
`mk`/`rc`.

**Done when:** `xmake recudo plan9` produces a Plan 9 executable, and the
toolchain recipe drives `goken9cc`'s `mk`-based build without the user
installing anything by hand.

### Classic Macintosh (Retro68, m68k and PowerPC)

**Status:** not started; source and container both available.

[`autc04/Retro68`](https://github.com/autc04/Retro68) is a GCC-based
cross-compiler for System 6/7 on 68K and for PowerPC Macs. There is
**no prebuilt toolchain release** — the last release (v2019.8.2) is source
only, and building takes 30-60 minutes plus boost, gmp, mpfr, libmpc, bison,
texinfo, ruby and flex. A ready-made container is published at
`ghcr.io/autc04/retro68`, and Nix users can `nix develop github:autc04/Retro68#m68k`.

Headers matter: Apple's Universal Interfaces "may not be redistributed", so
Retro68 ships the open-source **Multiversal Interfaces** instead. They are
incomplete — no Carbon, MacTCP, OpenTransport, Navigation Services, or anything
after System 7.0.

Cost: either bundle the container image (like `evc3`) or accept a source build
in `on_install`, which conflicts with the "download and extract" model the rest
of the recipes follow.

**Done when:** `xmake recudo mac68k` emits a runnable application and it boots in
Basilisk II or Mini vMac.

### Windows NT classic (Microsoft Visual C++ 4.x)

**Status:** not started; spec exists in dotstar, licensing unresolved.

The dotstar project carried a `vc4` spec for MSVC 4.x, used to build for
Windows NT 3.51/4.0 on **i386, Alpha AXP, MIPS and PowerPC** — four
architectures that no modern compiler targets and that nothing else in Recudo
can reach. It ran the 32-bit PE tools through `wibo`, exactly like `evc3`.

The blockers are the same as `evc3` and worse:

- there is no public download; the media is on archive.org as part of MSDN sets,
  not as a standalone product;
- the toolchain needs a full install tree, not a compiler binary, so it has to be
  assembled and re-hosted;
- Microsoft's licence for these toolchains is not a redistributable one, which is
  the reason `evc3` is documented as "preservation use" and why the same caveat
  would apply here;
- a separate `msvc-ia64` spec existed for Itanium (MSVC 2005 + Server 2003 PSDK).

**Done when:** the licensing question is answered first — either Microsoft
permits redistribution of the NT-era toolchains (it does not appear to), or the
platform is declared build-from-your-own-media only, with the recipe accepting a
user-supplied path. Only then is `xmake recudo nt-x86` meaningful.

### Haiku

**Status:** not started; two viable sources.

Haiku publishes a maintained script for prebuilt cross-toolchains:
[`haiku/haiku-toolchains-ubuntu`](https://github.com/haiku/haiku-toolchains-ubuntu)
has `fetch.sh --buildtools --arch=<x86_64|arm64|riscv64>` (needs `jq`), refreshed
monthly from the `buildtools` repo. That is the cheapest path — a real
download-and-extract, no build.

Alternative: `return/haiku-prebuilt-buildtools` (unofficial, for r1beta1) or the
`wischner/gcc-x86_64-haiku` container (1.8 GB, includes sysroot, headers, libs
and Jam).

Haiku's x86_64 target uses GCC 13; the 32-bit `x86_gcc2` hybrid needs both GCC 2
and GCC 13 for BeOS binary compatibility, and would be a separate package.

**Done when:** `xmake recudo haiku` builds an app that links `libbe` and starts
in a Haiku VM.

### Sharp X68000 / Human68k

**Status:** not started; the best option is a drop-in GCC toolchain.

[`yunkya2/elf2x68k`](https://github.com/yunkya2/elf2x68k) is the modern choice:
an **unmodified** `m68k-elf` GCC/binutils toolchain plus a specs-file hook
(`m68k-xelf-ld.x`) that converts the linked ELF into Humal68k's **X format** at
link time. From the user's side it is ordinary GCC:

```sh
m68k-xelf-gcc -o sample.x sample.c     # writes sample.x and sample.x.elf
```

Pinned components in the current release (`20260930`): binutils 2.46.0, GCC
13.5.0, newlib 4.6.0.20260123, GDB 17.2 — plus a `-gcc16` variant that the
author flags as experimental (GCC 16 generates slower and larger m68k code than
GCC 13).

Releases ship **prebuilt Linux binaries**; macOS builds from source through
Homebrew (`brew install yunkya2/tap/elf2x68k`, ~30 min on an M3). Remote
debugging works through [`gdbserver-x68k`](https://github.com/yunkya2/gdbserver-x68k).

Why this one and not the alternatives: [`erique/human68k-gcc`](https://github.com/erique/human68k-gcc)
patches GCC/binutils deeply to add a `m68k-human68k` target (GCC 6.5.0), which
means maintaining those patches across upgrades. elf2x68k touches neither,
so bumping GCC is a version change, not a port. It also links against either
newlib or the original Sharp XC libraries (`x68k2elf.py` converts native
objects).

Recipe shape: the Linux release is a plain archive, so this fits the existing
`toolchain_tree` pattern directly. The only unusual bit is that the X-format
conversion lives in a specs file inside the install tree, so the recipe must
preserve `lib/gcc/.../specs` paths exactly — a good target for the
`copy_tree`/`descend` helpers already in place.

**Done when:** `xmake recudo x68k` emits a `.x` executable that runs in an
emulator (run68, XM6, or on hardware).

### Watt-32 (TCP/IP for DOS)

**Status:** not started; this is a library, not a toolchain.

Watt-32 gives DOS programs a BSD-socket API. It supports Watcom C/C++ 11+ in
small/large/**flat** models (DOS4GW and PharLap extenders — `wattcpWF.lib` is
the flat one), plus djgpp, Borland, Metaware and native Win32/Win64.

Source of truth: [`gvanem/Watt-32`](https://github.com/gvanem/Watt-32)
(mirror of `watt-32.net`). Current release is **2.2 dev-rel.11 (July 2018)**:
sources 3.3 MB, binaries/examples 18 MB. At runtime it needs a packet driver
(`PKTDRVR`) — SwsVpkt or NDIS3PKT on real DOS.

Two ways to surface it in Recudo:

1. **As an xmake package** (`watt32`), building `wattcpWF.lib` with the `watcom`
   toolchain the repo already provisions. That is the honest fit: it is a
   library consumed by a target, not a compiler.
2. As an optional extra installed alongside `watcom`, exposed through
   `add_requires("watt32")` in a DOS project.

Complication: Watt-32's `makefile.wat` expects the legacy Watcom `wmake` layout
and DOS paths. Open Watcom v2 in the container may need the target flags passed
explicitly, and the libc it links against (`wattcp`) resolves DOS interrupts at
runtime, so a link succeeds without a packet driver present.

**Done when:** a DOS target can `#include <tcp.h>`, call `sock_init()`, and link
`wattcpWF.lib` through `add_requires`, with the recipe built by the `watcom`
toolchain during install.

### Atari 8-bit, C64, NES, Jaguar and friends

**Status:** buildable through `recudo.toolchain.vbcc`, not declared as platforms.

`vbcc` covers m68k, PPC and 6502 (C64, C128, PET, VIC-20, MEGA65, Commander X16,
NES, SNES, BBC Micro, Atari 8-bit, Apple II, Oric) plus vasm backends for Z80,
ARM, x86, PDP-11, 6809 and more. Verified working: `c64` (252 B program),
`nes` (iNES ROM, 2x16k PRG + 1x8k CHR), `aos68k` (1.2 KB), `tos` (1.4 KB),
`jaguar` (386 B).

Users can already build these with `add_rules("recudo.toolchain.vbcc")` and
`set_values("recudo.toolchain.vbcc.target", "c64")`. What is missing is first
class standing: a catalogue entry each, so `xmake recudo c64` works and
`xmake recudo list` reports them. That in turn needs output formats,
architecture names and host rules decided per platform.

**Done when:** `xmake recudo c64` (and `nes`, `atari8`) build from a project
root without any `add_rules` in the project file.

### vbcc assembly-only projects

**Status:** not supported; assembly mixes with C instead.

`vasm` handles assembly, but the binary distribution ships only the `bin`,
`vobj` and `test` output modules — `-Fcbm` and `-Felf` fail with
`could not initialize output module`. Consequences:

- `vc +c64 source.s` on its own fails: the frontend links a C runtime and wants
  `_main`. Assembly compiles fine (`vc +c64 -c file.s -o file.o`).
- Mixed projects work: `add_files("src/main.c", "src/raster.s")` — the `.c` goes
  through `vc`, the `.s` through xmake's own asm rule, and both objects meet in
  `on_linkcmd`.
- A pure-assembly C64 program cannot get its PRG header (`0x0801`) without the
  `cbm` output module.

Options if this becomes important: build vasm from source with all output
modules, or ship a separate `vasm` package with the full module set.

**Done when:** a project consisting only of `.s` files builds a runnable image.

---

## Emulation & Runtime Execution

### VM & Emulator Runner Subsystem (`recudo.vm` / `xmake recudo run`)

**Status:** prototyped in `dotstar/scripts/vm.lua` and `scripts/vms/`, not yet ported to Recudo.

Recudo excels at cross-compiling to retro and vintage targets (DOS, Windows CE,
AmigaOS, Atari ST, KolibriOS, Plan 9, OS/2, Haiku), but currently leaves the
runtime verification step entirely to the developer or custom project scripts.

The `dotstar` project served as the testbed and prototype ("father") of Recudo,
and carried a full VM/emulator orchestration engine:

- **Orchestrator (`scripts/vm.lua`):** boots guest emulators with target binaries
  injected, handles headless smoke testing or interactive sessions, and manages
  disk image generation / loopback mounting.
- **Engine Backends (`scripts/lib/vm/engines/`):**
  - **QEMU:** FreeDOS, Windows CE, KolibriOS, Plan 9 / 9front, BeOS, Haiku, MINIX, OS/2.
  - **FS-UAE / UAE:** AmigaOS (Classic m68k and AmigaOS 4 PPC).
  - **Hatari / Aranym:** Atari ST / TOS.
  - **DOSBox-X:** MS-DOS / PC-DOS.
- **Hardware & Device Passthrough (`scripts/lib/printer_passthrough.lua`, `printer_daemon.lua`):**
  - Host-to-guest USB printer passthrough via Linux sysfs.
  - Serial and parallel port redirection (pipes, TCP sockets, or hardware capture to files/PDF).

Porting this architecture into a first-class Recudo plugin (`recudo.vm` and
`xmake recudo run <platform>`) turns Recudo from a cross-compiler into a closed-loop
multi-die development environment: build, test, and run across all supported vintage
platforms directly from `xmake`.

**Done when:** `xmake recudo run --plat=freedos` (or `amiga`, `wince`, etc.)
provisions/locates the appropriate emulator, prepares the execution environment,
launches the target binary, and reports exit status.

---

## Testing

### Real SDK verification in CI

**Status:** the toolchain recipes are validated by hand, not in CI.

Every recipe was installed and exercised on a Linux host: AmigaOS (produced a
`loadseg()ble` binary), Atari mintelf and mint (TOS executables), KolibriOS
(`kos32-gcc 5.4.0`), Watcom (`wcl386`), eVC 3.0 (`clarm.exe` through wibo,
compiling ARM objects) and vbcc (five targets with native output).

CI runs the unit suite only (80 tests). Nothing in CI downloads a toolchain or
cross-compiles anything, so a recipe can rot between releases without a signal.

**Done when:** a CI job runs `xmake recudo tool install <toolchain>` and a smoke
build for the free-to-download toolchains (watcom, vbcc, amigaos-gcc,
atarist-mintelf, kolibrios-sdk), with download sizes and runtimes measured.

---

## Known rough edges

- `evc3`'s bundle still carries a stray `bin/wce300/` tree (35 duplicated files,
  no executables). Harmless — the toolchain reads `bin/` flat — but it costs
  roughly 4 MB of the archive.
- `evc3` is the only toolchain that depends on an artifact hosted by the project
  rather than by its upstream author, because Microsoft never distributed
  eVC 3.0 as a public download.
- `toolchains/vbcc.lua` declares the compiler paths but the per-target flag
  lives in the rule. Merging the two would make `--toolchain=vbcc` usable
  without `add_rules`, at the cost of the target becoming a project-wide
  setting instead of a per-target one.
