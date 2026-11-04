-- Projectum Lunare Recudo
-- Toolchain: vbcc (portable ISO C compiler) with vasm and vlink
--
-- One driver covers every backend vbcc ships, selected by a +target flag
-- instead of a per-target compiler prefix:
--   vc +c64 hello.c -o hello.prg
--
-- vbcc finds its target configurations through the VBCC environment variable,
-- which must point at the installation root (the directory holding config/).
-- Without it the driver aborts with "No config file!".
--
-- Targets that map to a platform Recudo already declares (amiga, atari) are
-- served by the GCC toolchains by default; vbcc is the alternative there and
-- the primary option for the 8-bit targets it is the only compiler for.

-- config id -> the platform id it builds for, when Recudo has one
local TARGETS = {
    ["aos68k"] = {plat = "amiga",  arch = "m68k"},
    ["kick13"] = {plat = "amiga",  arch = "m68k"},
    ["tos"]    = {plat = "atari",  arch = "m68k"},
    ["mint"]   = {plat = "atari",  arch = "m68k"},
    -- 8-bit and console targets: no Recudo platform yet, exposed for direct use
    ["c64"]    = {arch = "6502"},
    ["c128"]   = {arch = "6502"},
    ["pet"]    = {arch = "6502"},
    ["x16"]    = {arch = "6502"},
    ["m65"]    = {arch = "6502"},
    ["nes"]    = {arch = "6502"},
    ["atari"]  = {arch = "6502"},   -- Atari 8-bit home computers
    ["bbc"]    = {arch = "6502"},
    ["jaguar"] = {arch = "m68k"},
    ["aosppc"] = {plat = "amiga", arch = "ppc"},
    ["morphos"] = {arch = "ppc"},
    ["warpos"]  = {arch = "ppc"},
}

toolchain("vbcc")
    set_kind("standalone")
    set_homepage("http://www.compilers.de/vbcc.html")
    set_description("vbcc portable ISO C compiler (m68k, PPC, 6502: Amiga, Atari, C64, NES, Jaguar and more)")

    -- on_check runs outside the sandboxed import scope, so the SDK check
    -- goes straight to the environment instead of importing modules.sdk
    on_check(function (toolchain)
        local dir = os.getenv("VBCC")
        return dir ~= nil and dir ~= "" and os.isfile(path.join(dir, "bin", "vc"))
    end)

    on_load(function (toolchain)
        local root = os.getenv("VBCC")
        if not root or root == "" or not os.isdir(root) then
            raise("vbcc not found. Install it with: xmake recudo tool install vbcc")
        end

        local bindir = path.join(root, "bin")
        local vc = path.join(bindir, "vc")

        -- the driver dispatches to per-target backends; toolset keys point at
        -- the frontend so xmake records a real compiler, and the +target flag
        -- in cxflags selects the backend
        for _, kind in ipairs({"cc", "cxx", "ld"}) do
            toolchain:set("toolset", kind, vc)
        end
        toolchain:set("toolset", "ar", path.join(bindir, "vlink"))
        toolchain:set("toolset", "as", path.join(bindir, "vasmm68k_mot"))

        toolchain:add("envs", "PATH", bindir)
        -- the driver refuses to run without it
        toolchain:add("envs", "VBCC", root)

        -- target selection: the project declares it with
        --   set_values("recudo.toolchain.vbcc.target", "c64")
        local target = toolchain:get("values")
            and nil  -- resolved per target in the target rule below
        local arch = toolchain:arch() or "m68k"
        local cpu = {
            m68k = "-m68000",
            ["6502"] = "-m6502",
            ppc = "-mcpu=603",
        }
        toolchain:add("cxflags", cpu[arch] or "")
    end)
