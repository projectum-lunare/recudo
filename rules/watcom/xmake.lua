-- Projectum Lunare Forge
-- Rule: Open Watcom v2 C Compiler, Linker & Archiver (DOS 32-bit & OS/2 Warp)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function setup_watcom_rule(rule_name)
    rule(rule_name)
        set_extensions(".c")

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

            local argv = {
                "-b", target_sys,
                "-std=ow",
                "-O2",
                "-c",
                "-o", path.absolute(objfile)
            }

            for _, inc in ipairs(table.wrap(target:get("includedirs"))) do
                table.insert(argv, "-I" .. path.absolute(inc))
            end
            for _, def in ipairs(table.wrap(target:get("defines"))) do
                table.insert(argv, "-D" .. def)
            end

            local rel_source = path.relative(sourcefile, os.projectdir())
            table.insert(argv, rel_source)

            batchcmds:mkdir(path.directory(objfile))
            batchcmds:show_progress(opt.progress, "${color.build.object}compiling.watcom (%s) %s", target_sys, rel_source)
            batchcmds:vrunv(owcc, argv, {envs = envs, curdir = os.projectdir()})

            batchcmds:add_depfiles(sourcefile)
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
