-- Projectum Lunare Forge
-- Rule: Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function setup_evc3_rule(rule_name)
    rule(rule_name)
        set_extensions(".c")

        on_load(function (target)
            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../..")})
            local s = sdk.find("evc3", "EVC3_DIR")
            target:data_set("evc3.sdk", s)

            local wibo_bin = os.getenv("WIBO_BIN")
            if not wibo_bin then
                local wibo_dir = sdk.find("wibo", "WIBO_DIR")
                if wibo_dir then
                    wibo_bin = path.join(wibo_dir, "bin/wibo")
                end
            end
            target:data_set("evc3.wibo", wibo_bin)

            local arch = target:data("evc3.arch") or get_config("arch") or "arm"
            target:data_set("evc3.arch", arch)
        end)

        on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local s = target:data("evc3.sdk")
            local wibo = target:data("evc3.wibo")
            local arch = target:data("evc3.arch") or "arm"

            local comp_name = "clarm.exe"
            local arch_defs = {"_ARM_", "ARM"}
            if arch == "mips" then
                comp_name = "clmips.exe"
                arch_defs = {"_MIPS_", "MIPS"}
            elseif arch == "ppc" then
                comp_name = "clppc.exe"
                arch_defs = {"_PPC_", "PPC"}
            elseif arch == "sh3" then
                comp_name = "shcl.exe"
                arch_defs = {"_SH3_", "SH3", "SHx"}
            elseif arch == "sh4" then
                comp_name = "shcl.exe"
                arch_defs = {"_SH4_", "SH4", "SHx"}
            elseif arch == "x86" then
                comp_name = "cl.exe"
                arch_defs = {"_X86_", "x86"}
            end

            local cl_exe = path.join(s, "bin", comp_name)
            local objfile = target:objectfile(sourcefile)
            table.insert(target:objectfiles(), objfile)

            local envs = {
                INCLUDE = path.join(s, "include"),
                LIB = path.join(s, "lib", arch)
            }

            local argv = {
                cl_exe,
                "/nologo",
                "/c",
                "/O2",
                "/W3",
                "/DUNICODE",
                "/D_UNICODE",
                "/DUNDER_CE=300",
                "/D_WIN32_WCE=300",
                "/I" .. path.join(s, "include"),
                "/Fo" .. path.absolute(objfile)
            }

            for _, d in ipairs(arch_defs) do
                table.insert(argv, "/D" .. d)
            end
            for _, inc in ipairs(table.wrap(target:get("includedirs"))) do
                table.insert(argv, "/I" .. path.absolute(inc))
            end
            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "/D" .. def)
            end

            local rel_source = path.relative(sourcefile, os.projectdir())
            table.insert(argv, rel_source)

            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress, "${color.build.object}compiling.evc3 (%s) %s", arch, rel_source)
            batchcmds:vrunv(wibo, argv, {envs = envs, curdir = os.projectdir()})

            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)

        on_linkcmd(function (target, batchcmds, opt)
            local targetfile = target:targetfile()
            batchcmds:mkdir(path.directory(targetfile))
            batchcmds:show_progress(opt.progress, "${color.build.target}archiving.evc3 %s", targetfile)

            local argv = {"cr", path.absolute(targetfile)}
            for _, obj in ipairs(target:objectfiles()) do
                table.insert(argv, path.absolute(obj))
            end

            batchcmds:vrunv("ar", argv, {curdir = os.projectdir()})
        end)
end

setup_evc3_rule("evc3")
setup_evc3_rule("forge.evc3")
