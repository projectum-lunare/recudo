-- Projectum Lunare Forge
-- Rule: Open Watcom v2 C Compiler & Archiver (DOS 32-bit & OS/2 Warp)
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

            local envs = {
                WATCOM = sdkdir,
                EDPATH = path.join(sdkdir, "eddat"),
                PATH = bindir .. path.envsep() .. (os.getenv("PATH") or ""),
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
            local wlib = path.join(bindir, "wlib")
            local targetfile = target:targetfile()

            local envs = {
                WATCOM = sdkdir,
                EDPATH = path.join(sdkdir, "eddat"),
                PATH = bindir .. path.envsep() .. (os.getenv("PATH") or "")
            }

            local argv = {"-q", "-b", "-c", "-n", path.absolute(targetfile)}
            for _, obj in ipairs(target:objectfiles()) do
                table.insert(argv, "+" .. path.absolute(obj))
            end

            batchcmds:mkdir(path.directory(targetfile))
            batchcmds:show_progress(opt.progress, "${color.build.target}archiving.watcom %s", targetfile)
            batchcmds:vrunv(wlib, argv, {envs = envs, curdir = os.projectdir()})
        end)
end

setup_watcom_rule("watcom")
setup_watcom_rule("forge.watcom")
setup_watcom_rule("vintage.watcom")
