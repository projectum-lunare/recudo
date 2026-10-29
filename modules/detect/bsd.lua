-- Projectum Lunare Forge - BSD Architecture Normalization & Cross-Detection Module
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local arch_map = {
    amd64       = "x86_64",
    aarch64     = "arm64",
    powerpc     = "ppc",
    powerpc64   = "ppc64",
    powerpc64le = "ppc64le",
    powerpcspe  = "ppcspe",
    macppc      = "ppc",
    octeon      = "mips64",
    landisk     = "sh4",
    luna88k     = "m88k",
    itanium     = "ia64",
    rv32        = "riscv32",
    rv64        = "riscv64",
    riscv32     = "riscv32",
    riscv64     = "riscv64"
}

-- Normalize upstream architecture names to canonical Xmake identifiers
function normalize_arch(arch, plat)
    if not arch then return "x86_64" end
    local clean = arch:lower():trim()
    if clean == "riscv" then
        if plat == "netbsd" then
            -- NetBSD explicitly provides both riscv32 and riscv64 ports
            return "riscv64"
        else
            return "riscv64"
        end
    end
    return arch_map[clean] or clean
end

-- Resolve triple architecture identifier for GNU toolchains
function get_triple_arch(plat, arch)
    arch = normalize_arch(arch, plat)
    if arch == "arm64" then
        return "aarch64"
    elseif arch == "i386" and plat == "netbsd" then
        return "i486"
    end
    return arch
end

-- Generate cross-compilation toolchain prefixes for target BSD platform and architecture
function get_prefixes(plat, arch)
    arch = normalize_arch(arch, plat)
    local triple = get_triple_arch(plat, arch)
    local prefixes = {}

    local function add(p)
        for _, existing in ipairs(prefixes) do
            if existing == p then return end
        end
        table.insert(prefixes, p)
    end

    if plat == "netbsd" then
        add(triple .. "-netbsd-")
        add(triple .. "-unknown-netbsd-")
        add(triple .. "--netbsd-")
        add(triple .. "--netbsdelf-")
        add(triple .. "-netbsdelf-")
        if triple ~= arch then
            add(arch .. "-netbsd-")
            add(arch .. "-unknown-netbsd-")
            add(arch .. "--netbsd-")
            add(arch .. "--netbsdelf-")
            add(arch .. "-netbsdelf-")
        end
    elseif plat == "freebsd" then
        add(triple .. "-unknown-freebsd-")
        add(triple .. "-unknown-freebsd14-")
        add(triple .. "-unknown-freebsd13-")
        add(triple .. "-freebsd-")
        if triple ~= arch then
            add(arch .. "-freebsd-")
        end
    elseif plat == "openbsd" then
        add(triple .. "-unknown-openbsd-")
        add(triple .. "-openbsd-")
        if triple ~= arch then
            add(arch .. "-openbsd-")
        end
    elseif plat == "dragonflybsd" or plat == "dragonfly" then
        add("x86_64-unknown-dragonfly-")
        add("x86_64-dragonfly-")
    end

    return prefixes
end

-- Find cross-compiler prefix and binary for a given BSD platform
function find_toolchain(plat, arch, opt)
    opt = opt or {}
    local find_file = import("lib.detect.find_file")
    local prefixes = get_prefixes(plat, arch)
    local pathes = opt.bindir and {opt.bindir} or path.splitenv(os.getenv("PATH") or "")

    for _, pfx in ipairs(prefixes) do
        local tool = find_file(pfx .. "gcc", pathes) or find_file(pfx .. "clang", pathes)
        if tool then
            return pfx, tool
        end
    end
    return nil, nil
end

-- Check if BSD SDK / toolchain is available for platform and arch
function is_available(plat, arch, opt)
    opt = opt or {}
    if os.host() == plat then
        return true
    end

    local pfx, tool = find_toolchain(plat, arch, opt)
    if tool then
        return true
    end

    if plat == "netbsd" and os.getenv("NETBSD_TOOLDIR") then
        return true
    elseif plat == "freebsd" and os.getenv("FREEBSD_SYSROOT") then
        return true
    elseif plat == "openbsd" and os.getenv("OPENBSD_SYSROOT") then
        return true
    elseif (plat == "dragonflybsd" or plat == "dragonfly") and os.getenv("DRAGONFLY_SYSROOT") then
        return true
    end

    return false
end
