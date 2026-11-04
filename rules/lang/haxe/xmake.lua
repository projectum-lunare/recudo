-- Projectum Lunare Recudo - Haxe Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.haxe")
    set_extensions(".hx", ".hxml")

    on_load(function (target)
        local haxe = import("lang.haxe")
        local base = import("lang.base")
        base.ensure_package(target, "haxe")

        local b = haxe.backend(target)
        if b == "cpp" or b == "c++" then
            base.ensure_package(target, "hxcpp")
            local sourcekinds = target:sourcekinds()
            if not table.contains(sourcekinds, "cxx") then
                table.insert(sourcekinds, "cxx")
            end
            target._SOURCEKINDS_SET = nil
            local cpp_dir = path.join(target:autogendir(), "rules", "haxe", "cpp")
            target:add("includedirs", path.join(cpp_dir, "include"))
            target:add("includedirs", path.join(cpp_dir, "src"))
        elseif b == "lua" then
            if not target:data("recudo.lua.is_app") and not target:is_phony() and #target:objectfiles() == 0 then
                target:set("kind", "phony")
            end
        end
    end)

    before_build(function (target)
        if target:is_phony() then
            local haxe = import("lang.haxe")
            local base = import("lang.base")
            local haxe_prog = haxe.find_program(target)
            local outfile = target:values("recudo.lang.haxe.outfile")
            local b = haxe.backend(target)
            if not outfile and b == "lua" then
                local out_dir = base.outdir(target, "haxe")
                local base_name = target:basename() or target:name() or "main"
                outfile = path.join(out_dir, base_name .. ".lua")
            end
            local sourcefiles = {}
            for _, f in ipairs(table.wrap(target:sourcefiles())) do
                if f:endswith(".hx") or f:endswith(".hxml") then
                    table.insert(sourcefiles, f)
                end
            end
            if #sourcefiles > 0 then
                local argv = haxe.build_argv(target, sourcefiles, outfile)
                local envs = haxe.search_envs(target)
                if outfile then
                    os.mkdir(path.directory(outfile))
                end
                cprint("${color.build.target}compiling.haxe (%s) %s", b, target:name())
                os.vrunv(haxe_prog, argv, {envs = envs})
            end
        end
    end)

    on_buildcmd_files(function (target, batchcmds, sourcebatch, opt)
        local haxe = import("lang.haxe")
        local base = import("lang.base")
        local haxe_prog = haxe.find_program(target)
        local b = haxe.backend(target)
        local envs = haxe.search_envs(target)

        if b == "cpp" or b == "c++" then
            local cpp_dir = path.join(target:autogendir(), "rules", "haxe", "cpp")
            local src_dir = path.join(cpp_dir, "src")
            local argv = haxe.build_argv(target, sourcebatch.sourcefiles, cpp_dir)

            -- Ensure C++ source directory exists and initial transpile has run so file list is available
            if not os.isdir(src_dir) then
                os.mkdir(cpp_dir)
                os.vrunv(haxe_prog, argv, {envs = envs})
            end

            batchcmds:show_progress(opt.progress, "${color.build.target}compiling.haxe (cpp) %s", target:name())
            batchcmds:mkdir(cpp_dir)
            batchcmds:vrunv(haxe_prog, argv, {envs = envs})

            -- Compile all generated C++ files with Xmake toolchain
            local all_cpp = os.files(path.join(src_dir, "**.cpp"))
            local is_static = target:is_static()
            for _, cpp_file in ipairs(all_cpp) do
                local fname = path.filename(cpp_file)
                local skip = false
                if is_static and fname == "__main__.cpp" then
                    skip = true
                elseif not is_static and fname == "__lib__.cpp" then
                    skip = true
                end
                if not skip then
                    local objfile = target:objectfile(cpp_file)
                    if not table.contains(target:objectfiles(), objfile) then
                        table.insert(target:objectfiles(), objfile)
                    end
                    batchcmds:compile(cpp_file, objfile)
                end
            end

            batchcmds:add_depfiles(sourcebatch.sourcefiles)
            if #all_cpp > 0 then
                batchcmds:set_depmtime(os.mtime(all_cpp[1]))
                batchcmds:set_depcache(target:dependfile(all_cpp[1]))
            end
        else
            -- Transpiled targets (lua, js, python, hl, etc.)
            local outfile = target:values("recudo.lang.haxe.outfile")
            if not outfile then
                local out_dir = base.outdir(target, "haxe")
                local base_name = target:basename() or target:name() or "main"
                local ext = (b == "lua" and ".lua") or (b == "js" and ".js") or (b == "python" and ".py") or (b == "hl" and ".hl") or ".out"
                outfile = path.join(out_dir, base_name .. ext)
            end

            base.build_transpiled_batch(target, batchcmds, sourcebatch, opt, {
                lang = "haxe",
                outfile = outfile,
                program = haxe_prog,
                envs = envs,
                argv = function (out)
                    return haxe.build_argv(target, sourcebatch.sourcefiles, out)
                end
            })
        end
    end)

    after_install(function (target)
        local haxe = import("lang.haxe")
        if haxe.backend(target) == "lua" then
            import("lang.base").install_transpiled(target, ".hx", "haxe")
        end
    end)
