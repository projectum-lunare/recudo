-- Projectum Lunare Forge
-- Rule: Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function scan_evc3_includes(filepath, searchdirs, visited, results)
    visited = visited or {}
    results = results or {}
    if visited[filepath] or not os.isfile(filepath) then return results end
    visited[filepath] = true
    for line in io.lines(filepath) do
        local inc = line:match('^%s*#%s*include%s*["<]([^">]+)[">]')
        if inc then
            local candidate = path.join(path.directory(filepath), inc)
            if os.isfile(candidate) then
                table.insert(results, candidate)
                scan_evc3_includes(candidate, searchdirs, visited, results)
            else
                for _, d in ipairs(searchdirs) do
                    candidate = path.join(d, inc)
                    if os.isfile(candidate) then
                        table.insert(results, candidate)
                        scan_evc3_includes(candidate, searchdirs, visited, results)
                        break
                    end
                end
            end
        end
    end
    return results
end

local function setup_evc3_rule(rule_name)
    rule(rule_name)
        set_extensions(".c", ".cc", ".cpp", ".cxx")

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

            local is_cxx = sourcefile:endswith(".cpp") or sourcefile:endswith(".cc") or sourcefile:endswith(".cxx")
            local envs = {
                INCLUDE = path.join(s, "include"),
                LIB = path.join(s, "lib", arch)
            }

            local argv = {
                cl_exe,
                "/nologo",
                "/c"
            }

            if is_cxx then
                table.insert(argv, "/TP")
            else
                table.insert(argv, "/TC")
            end

            -- Optimization mapping
            local opt_level = target:get("optimize")
            if not opt_level then
                opt_level = (is_mode and is_mode("debug")) and "none" or "fast"
            end
            if opt_level == "none" then
                table.insert(argv, "/Od")
            elseif opt_level == "smallest" then
                table.insert(argv, "/O1")
            else
                table.insert(argv, "/O2")
            end

            -- Debug symbols
            if target:get("symbols") or (is_mode and is_mode("debug")) then
                table.insert(argv, "/Z7")
            end

            -- Warnings
            local warnings = target:get("warnings")
            if warnings == "none" then
                table.insert(argv, "/w")
            elseif warnings == "all" or warnings == "everything" then
                table.insert(argv, "/W4")
            elseif warnings == "error" then
                table.insert(argv, "/WX")
            else
                table.insert(argv, "/W3")
            end

            -- Built-in CE defines
            table.insert(argv, "/DUNICODE")
            table.insert(argv, "/D_UNICODE")
            table.insert(argv, "/DUNDER_CE=300")
            table.insert(argv, "/D_WIN32_WCE=300")
            table.insert(argv, "/I" .. path.join(s, "include"))

            for _, d in ipairs(arch_defs) do
                table.insert(argv, "/D" .. d)
            end

            -- Target defines
            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "/D" .. def)
            end

            -- Target includedirs
            local incdirs = table.join(table.wrap(target:get("includedirs")), table.wrap(target:get("sysincludedirs")))
            for _, inc in ipairs(incdirs) do
                table.insert(argv, "/I" .. path.absolute(inc))
            end

            -- Target cxflags, cflags, cxxflags
            for _, flag in ipairs(table.wrap(target:get("cxflags"))) do
                table.insert(argv, flag)
            end
            if is_cxx then
                for _, flag in ipairs(table.wrap(target:get("cxxflags"))) do
                    table.insert(argv, flag)
                end
            else
                for _, flag in ipairs(table.wrap(target:get("cflags"))) do
                    table.insert(argv, flag)
                end
            end

            table.insert(argv, "/Fo" .. path.absolute(objfile))

            local rel_source = path.relative(sourcefile, os.projectdir())
            table.insert(argv, rel_source)

            batchcmds:mkdir(path.directory(objfile))
            local comp_tag = is_cxx and "compiling.evc3.c++" or "compiling.evc3"
            batchcmds:show_progress(opt.progress, "${color.build.object}%s (%s) %s", comp_tag, arch, rel_source)
            batchcmds:vrunv(wibo, argv, {envs = envs, curdir = os.projectdir()})

            -- Header dependency tracking via recursive include scanning
            local searchdirs = table.join({path.directory(sourcefile)}, incdirs, {path.join(s, "include")})
            local depfiles = {sourcefile}
            local headers = scan_evc3_includes(sourcefile, searchdirs)
            for _, h in ipairs(headers) do
                table.insert(depfiles, h)
            end

            batchcmds:add_depfiles(table.unpack(depfiles))
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
