-- Projectum Lunare Recudo
-- Toolchains: AmigaOS and Atari ST m68k GCC
-- One loader. modules/catalog.lua keeps the per-target prefix, SDK and flags.

includes(path.join(os.scriptdir(), "../modules/catalog.lua"))

local function cpu_flag(arch)
    local flags = {
        m68020 = "-m68020",
        ["68020"] = "-m68020",
        m68030 = "-m68030",
        ["68030"] = "-m68030",
        m68040 = "-m68040",
        ["68040"] = "-m68040",
        m68060 = "-m68060",
        ["68060"] = "-m68060",
        ["m68020-40"] = "-m68020-40",
        ["m68020-60"] = "-m68020-60"
    }
    return flags[arch] or "-m68000"
end

local function define(spec)
    toolchain(spec.name)
        set_kind("standalone")
        set_homepage(spec.homepage)
        set_description(spec.description)

        on_check(function (toolchain)
            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
            return sdk.exists(spec.sdk_name, spec.sdk_env, {check_file = spec.check_file})
        end)

        on_load(function (toolchain)
            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
            local sdkdir = sdk.find(spec.sdk_name, spec.sdk_env)
            local bindir = path.join(sdkdir, "bin")
            local prefix = spec.prefix
            local tools = {
                cc = prefix .. "gcc",
                cxx = prefix .. "g++",
                ld = prefix .. "gcc",
                ar = prefix .. "ar",
                as = prefix .. "as",
                ranlib = prefix .. "ranlib"
            }
            for _, kind in ipairs({"cc", "cxx", "ld", "ar", "as", "ranlib"}) do
                toolchain:set("toolset", kind, path.join(bindir, tools[kind]))
            end
            toolchain:add("envs", "PATH", bindir)

            local arch = toolchain:arch() or get_config("arch") or "m68k"
            local flags = {"-std=gnu89", cpu_flag(arch)}
            for _, flag in ipairs(spec.tail_flags) do
                table.insert(flags, flag)
            end
            toolchain:add("cxflags", table.unpack(flags))
        end)
end

for _, spec in ipairs(gcc_toolchains()) do
    define(spec)
end

_dismiss()
