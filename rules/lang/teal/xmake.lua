-- Projectum Lunare Recudo - Teal Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local function find_teal_program(target)
    -- 1. Check if package "tl" is installed or bound to target
    if target and target.pkg then
        local pkg = target:pkg("tl")
        if pkg then
            local bindir = pkg:installdir("bin")
            if bindir then
                local prog = path.join(bindir, is_host("windows") and "tl.bat" or "tl")
                if os.isfile(prog) or os.isexec(prog) then
                    return prog
                end
            end
        end
    end

    -- 2. Check if xrepo has tl installed
    local xmake_pkg_tl = path.join(os.getenv("HOME") or "", ".xmake/packages/t/tl")
    if os.isdir(xmake_pkg_tl) then
        local matches = os.files(path.join(xmake_pkg_tl, "**/bin/tl"))
        if matches and #matches > 0 then
            return matches[1]
        end
    end

    -- 3. Check system PATH
    import("lib.detect.find_tool")
    local tool = find_tool("tl")
    if tool and tool.program then
        return tool.program
    end

    return "tl"
end

local function setup_teal_rule(rule_name)
    rule(rule_name)
        set_extensions(".tl")

        on_load(function (target)
            -- Auto-add tl package dependency if available and not already added
            local has_tl = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "tl" then
                    has_tl = true
                    break
                end
            end
            if not has_tl then
                target:add("packages", "tl")
            end
        end)

        before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            import("lua.env")

            local tl_prog = find_teal_program(target)
            local relpath = env.get_relative_path(target, sourcefile)
            local lua_rel = (relpath:gsub("%.tl$", ".lua"))

            -- Determine output destination
            local outdir = target:values("recudo.lang.teal.outdir")
            if not outdir then
                if target:data("recudo.lua.is_cmodule") or target:data("recudo.lua.is_pure") or target:data("recudo.lua.is_app") or target:data("recudo.engine.love") or target:data("recudo.engine.amulet") or target:has_rules("recudo.engine.love") or target:has_rules("recudo.engine.amulet") then
                    outdir = path.join(os.projectdir(), "build/lua")
                else
                    outdir = path.join(target:autogendir(), "rules", "teal")
                end
            end

            local outfile = path.join(outdir, lua_rel)

            -- Prepare tl gen command arguments
            local argv = {"gen"}
            local check_val = target:values("recudo.lang.teal.check")
            if check_val ~= false then
                table.insert(argv, "-c")
            end
            table.insert(argv, "-o")
            table.insert(argv, path(outfile))
            table.insert(argv, path(sourcefile))

            batchcmds:show_progress(opt.progress, "${color.build.target}transpiling.teal %s", sourcefile)
            batchcmds:mkdir(path.directory(outfile))
            batchcmds:vrunv(tl_prog, argv)
            batchcmds:add_depfiles(sourcefile)
            batchcmds:set_depmtime(os.mtime(outfile))
            batchcmds:set_depcache(target:dependfile(outfile))
        end)

        after_install(function (target)
            import("lua.env")
            local installdir = target:installdir()
            if not installdir then return end

            local outdir = target:values("recudo.lang.teal.outdir") or path.join(os.projectdir(), "build/lua")
            for _, src in ipairs(table.wrap(target:sourcefiles())) do
                if src:endswith(".tl") then
                    local relpath = env.get_relative_path(target, src)
                    local lua_rel = (relpath:gsub("%.tl$", ".lua"))
                    local gen_file = path.join(outdir, lua_rel)
                    if not os.isfile(gen_file) then
                        gen_file = path.join(target:autogendir(), "rules", "teal", lua_rel)
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

setup_teal_rule("recudo.lang.teal")
