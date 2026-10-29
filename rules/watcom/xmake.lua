-- Projectum Lunare Forge
-- Rule: Open Watcom v2 C Compiler, Linker & Archiver (DOS 32-bit & OS/2 Warp)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function setup_watcom_rule(rule_name)
    rule(rule_name)
        set_extensions(".c", ".cc", ".cpp", ".cxx")

        on_load(function (target)
            import("modules.sdk", {rootdir = path.join(os.scriptdir(), "../..")})
            local sdkdir = sdk.find("watcom", "WATCOM", {fallbacks = "C:\\WATCOM"})
            target:data_set("watcom.sdk", sdkdir)

            local bindir = path.join(sdkdir, "binl64")
            if not os.isdir(bindir) then
                bindir = path.join(sdkdir, "binl")
            end
            if not os.isdir(bindir) then
                bindir = path.join(sdkdir, "binnt64")
            end
            if not os.isdir(bindir) then
                bindir = path.join(sdkdir, "binnt")
            end
            target:data_set("watcom.bindir", bindir)

            local target_sys = target:data("watcom.target")
            if not target_sys then
                if target:is_plat("os2") then
                    target_sys = "os2v2"
                else
                    target_sys = "dos32a"
                end
                target:data_set("watcom.target", target_sys)
            end
        end)

        on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local sdkdir = target:data("watcom.sdk")
            local bindir = target:data("watcom.bindir")
            local owcc = path.join(bindir, "owcc")
            local target_sys = target:data("watcom.target") or "dos32a"

            local objfile = target:objectfile(sourcefile)
            table.insert(target:objectfiles(), objfile)

            local inc_target = (target_sys == "os2v2") and path.join(sdkdir, "h/os2") or path.join(sdkdir, "h/dos")
            local inc_base = path.join(sdkdir, "h")

            local pathes = {bindir}
            local binw = path.join(sdkdir, "binw")
            if os.isdir(binw) then table.insert(pathes, binw) end
            local binp = path.join(sdkdir, "binp")
            if os.isdir(binp) then table.insert(pathes, binp) end
            if os.getenv("PATH") then table.insert(pathes, os.getenv("PATH")) end

            local envs = {
                WATCOM = sdkdir,
                EDPATH = path.join(sdkdir, "eddat"),
                PATH = table.concat(pathes, path.envsep()),
                INCLUDE = inc_base .. path.envsep() .. inc_target
            }

            local is_cxx = sourcefile:endswith(".cpp") or sourcefile:endswith(".cc") or sourcefile:endswith(".cxx")
            local argv = {
                "-b", target_sys
            }

            if is_cxx then
                table.insert(argv, "-xc++")
            else
                table.insert(argv, "-std=ow")
            end

            -- Optimization mapping
            local opt_level = target:get("optimize")
            if not opt_level then
                opt_level = (is_mode and is_mode("debug")) and "none" or "fast"
            end
            if opt_level == "none" then
                table.insert(argv, "-O0")
            elseif opt_level == "smallest" then
                table.insert(argv, "-Os")
            else
                table.insert(argv, "-O2")
            end

            -- Debug symbols
            if target:get("symbols") or (is_mode and is_mode("debug")) then
                table.insert(argv, "-g2")
            end

            -- Warnings
            local warnings = target:get("warnings")
            if warnings == "none" then
                table.insert(argv, "-Wlevel=0")
            elseif warnings == "less" then
                table.insert(argv, "-Wlevel=1")
            elseif warnings == "all" or warnings == "everything" then
                table.insert(argv, "-Wextra")
            elseif warnings == "error" then
                table.insert(argv, "-Werror")
            else
                table.insert(argv, "-Wall")
            end

            -- Includedirs
            local incdirs = table.join(table.wrap(target:get("includedirs")), table.wrap(target:get("sysincludedirs")))
            for _, inc in ipairs(incdirs) do
                table.insert(argv, "-I" .. path.absolute(inc))
            end

            -- Defines
            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "-D" .. def)
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

            table.insert(argv, "-c")
            table.insert(argv, "-o")
            table.insert(argv, path.absolute(objfile))

            -- Autodependency tracking via -MMD -MF
            local depfile = target:dependfile(objfile) .. ".d"
            table.insert(argv, "-MMD")
            table.insert(argv, "-MF")
            table.insert(argv, path.absolute(depfile))

            local rel_source = path.relative(sourcefile, os.projectdir())
            table.insert(argv, rel_source)

            batchcmds:mkdir(path.directory(objfile))
            batchcmds:mkdir(path.directory(depfile))
            local comp_tag = is_cxx and "compiling.watcom.c++" or "compiling.watcom"
            batchcmds:show_progress(opt.progress, "${color.build.object}%s (%s) %s", comp_tag, target_sys, rel_source)
            batchcmds:vrunv(owcc, argv, {envs = envs, curdir = os.projectdir()})

            -- Header dependency tracking
            local depfiles = {sourcefile}
            if os.isfile(depfile) then
                local parse_deps = import("core.tools.gcc.parse_deps", {anonymous = true})
                local content = io.readfile(depfile)
                if content and parse_deps then
                    local parsed = parse_deps(content, os.projectdir())
                    if parsed then
                        for _, d in ipairs(parsed) do
                            local d_abs = path.is_absolute(d) and d or path.join(os.projectdir(), d)
                            if d_abs ~= path.absolute(objfile) and d_abs ~= path.absolute(sourcefile) and os.isfile(d_abs) then
                                table.insert(depfiles, d_abs)
                            end
                        end
                    end
                end
            else
                -- Fallback scan for direct local headers before first build
                for line in io.lines(sourcefile) do
                    local inc = line:match('^%s*#%s*include%s*["<]([^">]+)[">]')
                    if inc then
                        local src_dir = path.directory(sourcefile)
                        local candidate = path.join(src_dir, inc)
                        if os.isfile(candidate) then
                            table.insert(depfiles, candidate)
                        else
                            for _, d in ipairs(incdirs) do
                                candidate = path.join(d, inc)
                                if os.isfile(candidate) then
                                    table.insert(depfiles, candidate)
                                    break
                                end
                            end
                        end
                    end
                end
            end

            batchcmds:add_depfiles(table.unpack(depfiles))
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)

        on_linkcmd(function (target, batchcmds, opt)
            local sdkdir = target:data("watcom.sdk")
            local bindir = target:data("watcom.bindir")
            local target_sys = target:data("watcom.target") or (target:is_plat("os2") and "os2v2" or "dos32a")
            local targetfile = target:targetfile()

            local pathes = {bindir}
            local binw = path.join(sdkdir, "binw")
            if os.isdir(binw) then table.insert(pathes, binw) end
            local binp = path.join(sdkdir, "binp")
            if os.isdir(binp) then table.insert(pathes, binp) end
            if os.getenv("PATH") then table.insert(pathes, os.getenv("PATH")) end

            local envs = {
                WATCOM = sdkdir,
                EDPATH = path.join(sdkdir, "eddat"),
                PATH = table.concat(pathes, path.envsep())
            }

            batchcmds:mkdir(path.directory(targetfile))

            if target:is_binary() then
                local owcc = path.join(bindir, "owcc")
                local argv = {
                    "-b", target_sys,
                    "-o", path.absolute(targetfile)
                }

                for _, obj in ipairs(target:objectfiles()) do
                    table.insert(argv, path.absolute(obj))
                end
                for _, linkdir in ipairs(table.wrap(target:get("linkdirs"))) do
                    table.insert(argv, "-L" .. path.absolute(linkdir))
                end
                for _, link in ipairs(table.wrap(target:get("links"))) do
                    table.insert(argv, "-l" .. link)
                end
                for _, ldflag in ipairs(table.wrap(target:get("ldflags"))) do
                    table.insert(argv, ldflag)
                end
                for _, shflag in ipairs(table.wrap(target:get("shflags"))) do
                    table.insert(argv, shflag)
                end

                batchcmds:show_progress(opt.progress, "${color.build.target}linking.watcom (%s) %s", target_sys, targetfile)
                batchcmds:vrunv(owcc, argv, {envs = envs, curdir = os.projectdir()})
            elseif target:is_shared() then
                local owcc = path.join(bindir, "owcc")
                local argv = {
                    "-bd",
                    "-b", target_sys,
                    "-o", path.absolute(targetfile)
                }

                for _, obj in ipairs(target:objectfiles()) do
                    table.insert(argv, path.absolute(obj))
                end
                for _, linkdir in ipairs(table.wrap(target:get("linkdirs"))) do
                    table.insert(argv, "-L" .. path.absolute(linkdir))
                end
                for _, link in ipairs(table.wrap(target:get("links"))) do
                    table.insert(argv, "-l" .. link)
                end
                for _, ldflag in ipairs(table.wrap(target:get("ldflags"))) do
                    table.insert(argv, ldflag)
                end
                for _, shflag in ipairs(table.wrap(target:get("shflags"))) do
                    table.insert(argv, shflag)
                end

                batchcmds:show_progress(opt.progress, "${color.build.target}linking.watcom.dll (%s) %s", target_sys, targetfile)
                batchcmds:vrunv(owcc, argv, {envs = envs, curdir = os.projectdir()})
            else
                local wlib = path.join(bindir, "wlib")
                local argv = {"-q", "-b", "-c", "-n", path.absolute(targetfile)}
                for _, obj in ipairs(target:objectfiles()) do
                    table.insert(argv, "+" .. path.absolute(obj))
                end

                batchcmds:show_progress(opt.progress, "${color.build.target}archiving.watcom %s", targetfile)
                batchcmds:vrunv(wlib, argv, {envs = envs, curdir = os.projectdir()})
            end
        end)
end

setup_watcom_rule("watcom")
setup_watcom_rule("forge.watcom")
