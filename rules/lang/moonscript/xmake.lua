-- Projectum Lunare Forge - MoonScript Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local function find_moonscript_program(target)
    -- 1. Check if package "moonscript" is installed or bound to target
    if target and target.pkg then
        local pkg = target:pkg("moonscript")
        if pkg then
            local bindir = pkg:installdir("bin")
            if bindir then
                local prog = path.join(bindir, is_host("windows") and "moonc.bat" or "moonc")
                if os.isfile(prog) or os.isexec(prog) then
                    return prog
                end
            end
        end
    end

    -- 2. Check if xrepo has moonscript installed
    local xmake_pkg = path.join(os.getenv("HOME") or "", ".xmake/packages/m/moonscript")
    if os.isdir(xmake_pkg) then
        local matches = os.files(path.join(xmake_pkg, "**/bin/moonc"))
        if matches and #matches > 0 then
            return matches[1]
        end
    end

    -- 3. Check system PATH
    import("lib.detect.find_tool")
    local tool = find_tool("moonc")
    if tool and tool.program then
        return tool.program
    end

    return "moonc"
end

local function setup_moonscript_rule(rule_name)
    rule(rule_name)
        set_extensions(".moon")

        on_load(function (target)
            local has_pkg = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "moonscript" then
                    has_pkg = true
                    break
                end
            end
            if not has_pkg then
                target:add("packages", "moonscript")
            end
        end)

        before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            import("lua.env")

            local moonc_prog = find_moonscript_program(target)
            local relpath = env.get_relative_path(target, sourcefile)
            local lua_rel = (relpath:gsub("%.moon$", ".lua"))

            -- Determine output destination
            local outdir = target:values("forge.moonscript.outdir")
            if not outdir then
                if target:data("forge.lua.is_cmodule") or target:data("forge.lua.is_pure") or target:data("forge.lua.is_app") or target:data("forge.love") or target:data("forge.amulet") then
                    outdir = path.join(os.projectdir(), "build/lua")
                else
                    outdir = path.join(target:autogendir(), "rules", "moonscript")
                end
            end

            local outfile = path.join(outdir, lua_rel)

            -- Prepare moonc compile command arguments
            local argv = {}
            if target:values("forge.moonscript.correlate") or target:values("forge.moon.correlate") then
                table.insert(argv, "-c")
            end
            table.insert(argv, "-o")
            table.insert(argv, path(outfile))
            table.insert(argv, path(sourcefile))

            batchcmds:show_progress(opt.progress, "${color.build.target}transpiling.moonscript %s", sourcefile)
            batchcmds:mkdir(path.directory(outfile))
            batchcmds:vrunv(moonc_prog, argv)
            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(outfile))
            batchcmds:set_depcache(target:dependfile(outfile))
        end)

        after_install(function (target)
            import("lua.env")
            local installdir = target:installdir()
            if not installdir then return end

            local outdir = target:values("forge.moonscript.outdir") or path.join(os.projectdir(), "build/lua")
            for _, src in ipairs(table.wrap(target:sourcefiles())) do
                if src:endswith(".moon") then
                    local relpath = env.get_relative_path(target, src)
                    local lua_rel = (relpath:gsub("%.moon$", ".lua"))
                    local gen_file = path.join(outdir, lua_rel)
                    if not os.isfile(gen_file) then
                        gen_file = path.join(target:autogendir(), "rules", "moonscript", lua_rel)
                    end
                    if os.isfile(gen_file) then
                        local dst_share = path.join(installdir, "share/lua", lua_rel)
                        local dst_lib = path.join(installdir, "lib", lua_rel)
                        os.mkdir(path.directory(dst_share))
                        os.mkdir(path.directory(dst_lib))
                        os.cp(gen_file, dst_share)
                        os.cp(gen_file, dst_lib)
                    end
                end
            end
        end)
end

setup_moonscript_rule("forge.lang.moonscript")
