-- Projectum Lunare Forge - Nelua Systems Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

local function find_nelua_program(target)
    -- 1. Check if package "nelua" is installed or bound to target
    if target and target.pkg then
        local pkg = target:pkg("nelua")
        if pkg then
            local bindir = pkg:installdir("bin")
            if bindir then
                local prog = path.join(bindir, is_host("windows") and "nelua.bat" or "nelua")
                if os.isfile(prog) or os.isexec(prog) then
                    return prog
                end
            end
        end
    end

    -- 2. Check if xrepo has nelua installed
    local xmake_pkg_nelua = path.join(os.getenv("HOME") or "", ".xmake/packages/n/nelua")
    if os.isdir(xmake_pkg_nelua) then
        local matches = os.files(path.join(xmake_pkg_nelua, "**/bin/nelua*"))
        for _, match in ipairs(matches or {}) do
            local fn = path.filename(match)
            if fn == "nelua" or fn == "nelua.bat" then
                return match
            end
        end
    end

    -- 3. Check system PATH
    import("lib.detect.find_tool")
    local tool = find_tool("nelua")
    if tool and tool.program then
        return tool.program
    end

    return "nelua"
end

local function setup_nelua_rule(rule_name)
    rule(rule_name)
        add_deps("c", "c++")
        set_extensions(".nelua")

        on_load(function (target)
            -- Auto-add nelua package dependency if available and not already added
            local has_nelua = false
            for _, pkg in ipairs(table.wrap(target:get("packages"))) do
                if pkg == "nelua" then
                    has_nelua = true
                    break
                end
            end
            if not has_nelua then
                target:add("packages", "nelua")
            end
        end)

        before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local nelua_prog = find_nelua_program(target)
            local generator = target:values("forge.lang.nelua.generator") or "c"

            if generator == "lua" then
                import("lua.env")
                local relpath = env.get_relative_path(target, sourcefile)
                local lua_rel = (relpath:gsub("%.nelua$", ".lua"))

                local outdir = target:values("forge.lang.nelua.outdir")
                if not outdir then
                    if target:data("forge.lua.is_cmodule") or target:data("forge.lua.is_pure") or target:data("forge.lua.is_app") or target:data("forge.engine.love") or target:data("forge.engine.amulet") or target:has_rules("forge.engine.love") or target:has_rules("forge.engine.amulet") then
                        outdir = path.join(os.projectdir(), "build/lua")
                    else
                        outdir = path.join(target:autogendir(), "rules", "nelua")
                    end
                end

                local outfile = path.join(outdir, lua_rel)
                local argv = {"-g", "lua", "-c", path(sourcefile), "-o", path(outfile)}

                batchcmds:show_progress(opt.progress, "${color.build.target}transpiling.nelua %s", sourcefile)
                batchcmds:mkdir(path.directory(outfile))
                batchcmds:vrunv(nelua_prog, argv)
                batchcmds:add_depfiles(sourcefile)
                batchcmds:set_depmtime(os.mtime(outfile))
                batchcmds:set_depcache(target:dependfile(outfile))
            else
                -- Default: compile Nelua to C code and compile into target objectfiles
                local sourcefile_c = path.join(target:autogendir(), "rules", "nelua", path.basename(sourcefile) .. ".c")
                local objectfile = target:objectfile(sourcefile_c)
                table.insert(target:objectfiles(), objectfile)

                local argv = {"-c"}
                if target:is_mode("release") then
                    table.insert(argv, "-r")
                end
                if target:values("forge.lang.nelua.maximum_performance") then
                    table.insert(argv, "-M")
                end
                local defines = target:values("forge.lang.nelua.defines")
                for _, def in ipairs(table.wrap(defines)) do
                    table.insert(argv, "-D" .. def)
                end
                local pragmas = target:values("forge.lang.nelua.pragmas")
                for _, pragma in ipairs(table.wrap(pragmas)) do
                    table.insert(argv, "-P" .. pragma)
                end

                table.insert(argv, path(sourcefile))
                table.insert(argv, "-o")
                table.insert(argv, path(sourcefile_c))

                batchcmds:show_progress(opt.progress, "${color.build.object}compiling.nelua %s", sourcefile)
                batchcmds:mkdir(path.directory(sourcefile_c))
                batchcmds:vrunv(nelua_prog, argv)
                batchcmds:compile(sourcefile_c, objectfile)
                batchcmds:add_depfiles(sourcefile)
                batchcmds:set_depmtime(os.mtime(objectfile))
                batchcmds:set_depcache(target:dependfile(objectfile))
            end
        end)
end

setup_nelua_rule("forge.lang.nelua")
