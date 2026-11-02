-- Projectum Lunare Recudo - Fennel Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local function find_fennel_program(target)
    -- 1. Check if package "fennel" is installed or bound to target
    if target and target.pkg then
        local pkg = target:pkg("fennel")
        if pkg then
            local bindir = pkg:installdir("bin")
            if bindir then
                local prog = path.join(bindir, is_host("windows") and "fennel.bat" or "fennel")
                if os.isfile(prog) or os.isexec(prog) then
                    return prog
                end
            end
        end
    end

    -- 2. Check if xrepo has fennel installed
    local xmake_pkg_fennel = path.join(os.getenv("HOME") or "", ".xmake/packages/f/fennel")
    if os.isdir(xmake_pkg_fennel) then
        local matches = os.files(path.join(xmake_pkg_fennel, "**/bin/fennel"))
        if matches and #matches > 0 then
            return matches[1]
        end
    end

    -- 3. Check system PATH
    import("lib.detect.find_tool")
    local tool = find_tool("fennel")
    if tool and tool.program then
        return tool.program
    end

    return "fennel"
end

local function setup_fennel_rule(rule_name)
    rule(rule_name)
        set_extensions(".fnl")

        on_load(function (target)
            local has_pkg = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "fennel" then
                    has_pkg = true
                    break
                end
            end
            if not has_pkg then
                target:add("packages", "fennel")
            end
        end)

        before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            import("lua.env")

            local fennel_prog = find_fennel_program(target)
            local relpath = env.get_relative_path(target, sourcefile)
            local lua_rel = (relpath:gsub("%.fnl$", ".lua"))

            -- Determine output destination
            local outdir = target:values("recudo.lang.fennel.outdir")
            if not outdir then
                if target:data("recudo.lua.is_cmodule") or target:data("recudo.lua.is_pure") or target:data("recudo.lua.is_app") or target:data("recudo.engine.love") or target:data("recudo.engine.amulet") or target:has_rules("recudo.engine.love") or target:has_rules("recudo.engine.amulet") then
                    outdir = path.join(os.projectdir(), "build/lua")
                else
                    outdir = path.join(target:autogendir(), "rules", "fennel")
                end
            end

            local outfile = path.join(outdir, lua_rel)

            -- Prepare fennel compile command arguments
            local argv = {"--compile"}
            if target:values("recudo.lang.fennel.correlate") then
                table.insert(argv, "--correlate")
            end
            if target:values("recudo.lang.fennel.require_as_include") then
                table.insert(argv, "--require-as-include")
            end
            table.insert(argv, path(sourcefile))

            batchcmds:show_progress(opt.progress, "${color.build.target}transpiling.fennel %s", sourcefile)
            batchcmds:mkdir(path.directory(outfile))
            batchcmds:vrunv(fennel_prog, argv, {stdout = outfile})
            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(outfile))
            batchcmds:set_depcache(target:dependfile(outfile))
        end)

        after_install(function (target)
            import("lua.env")
            local installdir = target:installdir()
            if not installdir then return end

            local outdir = target:values("recudo.lang.fennel.outdir") or path.join(os.projectdir(), "build/lua")
            for _, src in ipairs(table.wrap(target:sourcefiles())) do
                if src:endswith(".fnl") then
                    local relpath = env.get_relative_path(target, src)
                    local lua_rel = (relpath:gsub("%.fnl$", ".lua"))
                    local gen_file = path.join(outdir, lua_rel)
                    if not os.isfile(gen_file) then
                        gen_file = path.join(target:autogendir(), "rules", "fennel", lua_rel)
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

setup_fennel_rule("recudo.lang.fennel")
