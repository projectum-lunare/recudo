-- Projectum Lunare Recudo
-- Rule: Open Watcom v2 C Compiler, Linker & Archiver (DOS 32-bit & OS/2 Warp)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function append_flags(argv, flags)
    for _, flag in ipairs(table.wrap(flags)) do
        -- package.tools.xmake injects -fPIC for non-Windows packages.
        -- Open Watcom does not use position-independent code.
        if flag ~= "-fPIC" and flag ~= "-fpic" and flag ~= "-fPIE" and flag ~= "-fpie" then
            table.insert(argv, flag)
        end
    end
end

local function setup_watcom_rule(rule_name)
    rule(rule_name)
        set_extensions(".c", ".cc", ".cpp", ".cxx")

        on_load(function (target)
            local root = path.join(os.scriptdir(), "../../..")
            import("modules.detect.watcom", {rootdir = root})
            local entry = import("catalog", {rootdir = path.join(root, "modules")}).get("dos")
            local sdkdir = watcom.find_sdk(entry.sdk_env, {sdk_name = entry.sdk_name})
            target:data_set("watcom.sdk", sdkdir)

            local bindir = watcom.find_bindir(sdkdir)
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
            import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "../../..")})
            local sdkdir = target:data("watcom.sdk")
            local bindir = target:data("watcom.bindir")
            local owcc = path.join(bindir, "owcc")
            local target_sys = target:data("watcom.target") or "dos32a"

            local objfile = target:objectfile(sourcefile)

            -- Deduplicated registration into target:objectfiles()
            local current_objs = target:objectfiles()
            if current_objs and not table.contains(current_objs, objfile) then
                table.insert(current_objs, objfile)
            end

            local envs = watcom.get_env(sdkdir, target_sys)

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

            -- Preprocessor defines
            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "-D" .. def)
            end

            -- Header search paths
            local incdirs = table.join(table.wrap(target:get("includedirs")), table.wrap(target:get("sysincludedirs")))
            for _, inc in ipairs(incdirs) do
                table.insert(argv, "-I" .. path.absolute(inc))
            end

            -- Custom compiler flags
            append_flags(argv, target:get("cxflags"))
            if is_cxx then
                append_flags(argv, target:get("cxxflags"))
            else
                append_flags(argv, target:get("cflags"))
            end

            -- Header dependency tracking via -MMD -MF
            local depfile = target:dependfile(objfile)
            table.insert(argv, "-MMD")
            table.insert(argv, "-MF")
            table.insert(argv, depfile)

            table.insert(argv, "-c")
            table.insert(argv, "-o")
            table.insert(argv, path.absolute(objfile))

            local rel_source = path.relative(sourcefile, os.projectdir())
            table.insert(argv, rel_source)

            batchcmds:mkdir(path.directory(objfile))
            batchcmds:mkdir(path.directory(depfile))

            local comp_tag = is_cxx and "compiling.watcom.c++" or "compiling.watcom"
            batchcmds:show_progress(opt.progress, "${color.build.object}%s (%s) %s", comp_tag, target_sys, rel_source)
            batchcmds:vrunv(owcc, argv, {envs = envs, curdir = os.projectdir()})

            -- Register dependency files
            local function parse_deps(dfile)
                if not os.isfile(dfile) then return {} end
                local content = io.readfile(dfile)
                if not content then return {} end
                content = content:gsub("\\\r?\n", " ")
                local colon = content:find(":")
                if colon then
                    content = content:sub(colon + 1)
                end
                local files = {}
                for item in content:gmatch("%S+") do
                    if os.isfile(item) then
                        table.insert(files, item)
                    end
                end
                return files
            end

            local depfiles = parse_deps(depfile)
            if #depfiles == 0 then
                table.insert(depfiles, sourcefile)
            end

            batchcmds:add_depfiles(table.unpack(depfiles))
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(depfile)
        end)

        on_linkcmd(function (target, batchcmds, opt)
            import("modules.detect.watcom", {rootdir = path.join(os.scriptdir(), "../../..")})
            local sdkdir = target:data("watcom.sdk")
            local bindir = target:data("watcom.bindir")
            local target_sys = target:data("watcom.target") or "dos32a"
            local targetfile = target:targetfile()

            local envs = watcom.get_env(sdkdir, target_sys)
            local objs = import("modules.objectfiles", {rootdir = path.join(os.scriptdir(), "../../..")}).collect(target)

            batchcmds:mkdir(path.directory(targetfile))

            if target:is_binary() then
                local owcc = path.join(bindir, "owcc")
                local argv = {
                    "-b", target_sys,
                    "-o", path.absolute(targetfile)
                }

                for _, obj in ipairs(objs) do
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

                for _, obj in ipairs(objs) do
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
                for _, obj in ipairs(objs) do
                    table.insert(argv, "+" .. path.absolute(obj))
                end

                batchcmds:show_progress(opt.progress, "${color.build.target}archiving.watcom %s", targetfile)
                batchcmds:vrunv(wlib, argv, {envs = envs, curdir = os.projectdir()})
            end
        end)
end

setup_watcom_rule("recudo.toolchain.watcom")
