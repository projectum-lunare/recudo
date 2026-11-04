-- Projectum Lunare Recudo
-- Rule: vbcc builds
--
-- vbcc selects its backend per invocation with a +target flag, so the rule
-- carries the target while the toolchain keeps the compiler path:
--
--   target("hello")
--       add_rules("recudo.toolchain.vbcc")
--       set_values("recudo.toolchain.vbcc.target", "c64")
--       add_files("src/*.c")
--
-- Verified targets (config/ of the vbcc package):
--   c64 c128 pet x16 m65 nes bbc atari  -> 6502 backends
--   aos68k kick13 tos mint jaguar       -> m68k backends
--   aosppc morphos warpos               -> ppc backends

local function setup_vbcc_rule(rule_name)
    rule(rule_name)
        -- C only. Assembly sources are handled by xmake's own asm rule, which
        -- already drives vasm; claiming the suffixes here would double-build
        -- them. The objects from either path meet in on_linkcmd below.
        set_extensions(".c")

        on_load(function (target)
            local vbcc_target = target:values("recudo.toolchain.vbcc.target") or "aos68k"
            target:data_set("vbcc.target", vbcc_target)

            -- the driver needs VBCC pointing at the install root
            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../../..")})
            local root = sdk.find("vbcc", "VBCC", {must_exist = true})
            if not root then
                raise("vbcc not found. Install it with: xmake recudo tool install vbcc")
            end
            target:data_set("vbcc.root", root)
        end)

        on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local root = target:data("vbcc.root")
            local vbcc_target = target:data("vbcc.target") or "aos68k"
            local bindir = path.join(root, "bin")
            local objfile = target:objectfile(sourcefile)

            local argv = {
                path.join(bindir, "vc"),
                "+" .. vbcc_target,
                "-c",
            }

            -- optimization
            local opt_level = target:get("optimize")
            if opt_level == "none" or (not opt_level and is_mode and is_mode("debug")) then
                table.insert(argv, "-O0")
            else
                table.insert(argv, "-O2")
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
                    table.wrap(target:get("cflags"))))) do
                table.insert(argv, flag)
            end

            table.insert(argv, "-o")
            table.insert(argv, path.absolute(objfile))
            table.insert(argv, path.relative(sourcefile, os.projectdir()))

            local envs = {
                VBCC = root,
                PATH = bindir .. path.envsep() .. (os.getenv("PATH") or ""),
            }

            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress,
                "${color.build.object}compiling.vbcc (%s) %s", vbcc_target,
                path.relative(sourcefile, os.projectdir()))
            batchcmds:vrunv(path.join(bindir, "vc"),
                table.slice(argv, 2), {envs = envs, curdir = os.projectdir()})
            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)

        -- vbcc links through the same frontend: vc +target <objs> -o <out>.
        -- For the console targets (c64, nes...) this emits a ready image; for
        -- the m68k targets it emits the TOS/AmigaOS executable.
        on_linkcmd(function (target, batchcmds, opt)
            local root = target:data("vbcc.root")
            local vbcc_target = target:data("vbcc.target") or "aos68k"
            local bindir = path.join(root, "bin")
            local targetfile = target:targetfile()

            batchcmds:mkdir(path.directory(targetfile))

            local objs = import("modules.objectfiles", {rootdir = path.join(os.scriptdir(), "../../..")}).collect(target)
            local argv = {"+" .. vbcc_target}
            for _, obj in ipairs(objs) do
                table.insert(argv, path.absolute(obj))
            end

            -- AmigaOS links only -lvc by default, and that is enough for
            -- integer-only programs (verified: they link clean without any
            -- math lib). Programs that use floating point pick the math
            -- library explicitly, because the need is theirs, not the rule's:
            --
            --   target("lualib")
            --       add_rules("recudo.toolchain.vbcc")
            --       set_values("recudo.toolchain.vbcc.math", "msoft")
            --
            -- The value maps 1:1 to the vbcc lib families (msoft = software
            -- float, mieee = MathIEEEDoubBas.library, m881/m040 = hardware
            -- FPU). For the aos68k config, which compiles with
            -- -amiga-softfloat, msoft is the verified pairing: lua fails to
            -- link with undefined _floor/_pow/_MathIeeeDoubBasBase without
            -- it.
            local mathlib = target:values("recudo.toolchain.vbcc.math")
            if mathlib and mathlib ~= "none" then
                table.insert(argv, "-l" .. mathlib)
            end

            table.insert(argv, "-o")
            table.insert(argv, path.absolute(targetfile))

            for _, flag in ipairs(table.wrap(target:get("ldflags"))) do
                table.insert(argv, flag)
            end

            local envs = {
                VBCC = root,
                PATH = bindir .. path.envsep() .. (os.getenv("PATH") or ""),
            }

            batchcmds:show_progress(opt.progress,
                "${color.build.target}linking.vbcc (%s) %s", vbcc_target,
                path.filename(targetfile))
            batchcmds:vrunv(path.join(bindir, "vc"), argv, {envs = envs, curdir = os.projectdir()})
        end)
end

setup_vbcc_rule("recudo.toolchain.vbcc")
