-- Projectum Lunare Recudo
-- Rule: Atari ST builds (MiNT GCC)
--
-- Two real toolchains exist for this target and both are package recipes:
--
--   atarist-mintelf  GCC 13.3.0, ELF objects, PRG/ELF output, GDB, C++13.
--                    Prefix m68k-atari-mintelf-, symbols without underscore.
--   atarist-mint     GCC 4.6.4, a.out objects, classic TOS executable,
--                    MonST2-compatible symbols via -Wl,--traditional-format,
--                    leading-underscore convention.
--
-- The rule picks the variant per target so a project can carry legacy code
-- and modern code side by side:
--
--   target("legacy")
--       add_rules("recudo.toolchain.atarist")
--       set_values("recudo.toolchain.atarist.variant", "mint")     -- classic
--       add_files("src/*.c")
--
--   target("modern")
--       add_rules("recudo.toolchain.atarist")                      -- mintelf default
--       add_files("src/*.c")
--
-- Both variants are detected through the SDK layer, which already understands
-- the ATARIST_MINTELF / ATARIST_SDK environment overrides and the
-- ~/.local/opt contract paths.

local VARIANTS = {
    mintelf = {
        sdk_name = "atarist-mintelf",
        sdk_env  = "ATARIST_MINTELF",
        prefix   = "m68k-atari-mintelf-",
        check    = "bin/m68k-atari-mintelf-gcc",
        -- ELF toolchain: no underscore prefix on C symbols
        flags    = {"-m68000"},
        ldflags  = {},
    },
    mint = {
        sdk_name = "atarist-mint",
        sdk_env  = "ATARIST_SDK",
        prefix   = "m68k-atari-mint-",
        check    = "bin/m68k-atari-mint-gcc",
        -- classic toolchain: keep DRI symbols readable by MonST2 and friends
        flags    = {"-m68000", "-std=gnu89"},
        ldflags  = {"-Wl,--traditional-format"},
    },
}

local function setup_atarist_rule(rule_name)
    rule(rule_name)
        set_extensions(".c", ".cc", ".cpp", ".cxx")

        on_load(function (target)
            local variant_name = target:values("recudo.toolchain.atarist.variant") or "mintelf"
            local variant = VARIANTS[variant_name]
            if not variant then
                raise("unknown atarist variant '%s' (available: mintelf, mint)", variant_name)
            end
            target:data_set("atarist.variant", variant)
            target:data_set("atarist.variant_name", variant_name)

            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../../..")})
            local dir = sdk.find(variant.sdk_name, variant.sdk_env)
            if not dir then
                raise("%s not found. Install it with: xmake recudo tool install %s",
                    variant_name, variant.sdk_name)
            end
            target:data_set("atarist.sdk", dir)

            -- CPU selection. get_config("arch") reports the *host* platform
            -- arch here (x86_64 on a Linux box), which is meaningless for an
            -- m68k target: only accept an explicit project value, and map the
            -- common aliases onto the gcc flag spelling.
            local cpu = target:values("recudo.toolchain.atarist.cpu") or "68000"
            local alias = {
                ["m68k"] = "68000", ["m68000"] = "68000", ["68000"] = "68000",
                ["m68020"] = "68020", ["68020"] = "68020",
                ["m68030"] = "68030", ["68030"] = "68030",
                ["m68040"] = "68040", ["68040"] = "68040",
                ["m68060"] = "68060", ["68060"] = "68060",
                ["m68020-60"] = "68020-60", ["68020-60"] = "68020-60",
            }
            target:data_set("atarist.cpu", alias[cpu] or "68000")
        end)

        on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local variant = target:data("atarist.variant")
            local sdkdir = target:data("atarist.sdk")
            local cpu = target:data("atarist.cpu") or "68000"
            local bindir = path.join(sdkdir, "bin")
            local objfile = target:objectfile(sourcefile)

            local is_cxx = sourcefile:endswith(".cpp") or sourcefile:endswith(".cc")
                or sourcefile:endswith(".cxx")
            local compiler = path.join(bindir, variant.prefix .. (is_cxx and "g++" or "gcc"))

            local argv = {compiler, "-c"}
            table.insert(argv, "-m" .. cpu)

            local opt_level = target:get("optimize")
            if opt_level == "none" or (not opt_level and is_mode and is_mode("debug")) then
                table.insert(argv, "-O0")
            elseif opt_level == "smallest" then
                table.insert(argv, "-Os")
            else
                table.insert(argv, "-O2")
            end

            if target:get("symbols") or (is_mode and is_mode("debug")) then
                table.insert(argv, "-g")
            end

            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "-D" .. def)
            end
            for _, inc in ipairs(table.wrap(table.join(
                    table.wrap(target:get("includedirs")),
                    table.wrap(target:get("sysincludedirs"))))) do
                table.insert(argv, "-I" .. path.absolute(inc))
            end
            for _, flag in ipairs(table.wrap(table.join(
                    table.wrap(target:get("cxflags")),
                    table.wrap(is_cxx and target:get("cxxflags") or target:get("cflags"))))) do
                table.insert(argv, flag)
            end

            table.insert(argv, "-o")
            table.insert(argv, path.absolute(objfile))
            table.insert(argv, path.relative(sourcefile, os.projectdir()))

            local tag = is_cxx and "compiling.atarist.c++" or "compiling.atarist"
            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress, "${color.build.object}" .. tag .. " (%s) %s",
                target:data("atarist.variant_name"), path.relative(sourcefile, os.projectdir()))
            batchcmds:vrunv(compiler, table.slice(argv, 2),
                {envs = {PATH = bindir .. path.envsep() .. (os.getenv("PATH") or "")},
                 curdir = os.projectdir()})

            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)

        on_linkcmd(function (target, batchcmds, opt)
            local variant = target:data("atarist.variant")
            local sdkdir = target:data("atarist.sdk")
            local cpu = target:data("atarist.cpu") or "68000"
            local bindir = path.join(sdkdir, "bin")
            local targetfile = target:targetfile()

            local objs = import("modules.objectfiles", {rootdir = path.join(os.scriptdir(), "../../..")}).collect(target)

            local argv = {path.join(bindir, variant.prefix .. "gcc")}
            for _, flag in ipairs(variant.ldflags) do
                table.insert(argv, flag)
            end
            table.insert(argv, "-m" .. cpu)
            table.insert(argv, "-o")
            table.insert(argv, path.absolute(targetfile))
            for _, obj in ipairs(objs) do
                table.insert(argv, path.absolute(obj))
            end
            for _, flag in ipairs(table.wrap(target:get("ldflags"))) do
                table.insert(argv, flag)
            end
            for _, linkdir in ipairs(table.wrap(target:get("linkdirs"))) do
                table.insert(argv, "-L" .. path.absolute(linkdir))
            end
            for _, link in ipairs(table.wrap(target:get("links"))) do
                table.insert(argv, "-l" .. link)
            end

            batchcmds:mkdir(path.directory(targetfile))
            batchcmds:show_progress(opt.progress,
                "${color.build.target}linking.atarist (%s) %s",
                target:data("atarist.variant_name"), path.filename(targetfile))
            batchcmds:vrunv(argv[1], table.slice(argv, 2),
                {envs = {PATH = bindir .. path.envsep() .. (os.getenv("PATH") or "")},
                 curdir = os.projectdir()})
        end)
end

setup_atarist_rule("recudo.toolchain.atarist")
