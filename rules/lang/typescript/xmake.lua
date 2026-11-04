-- Projectum Lunare Recudo - TypeScript Language Rule (TypeScriptToLua)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.typescript")
    set_extensions(".ts")

    on_load(function (target)
        import("lang.base").ensure_package(target, "typescript-to-lua")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "typescript",
            ext = ".ts",
            program = import("lang.typescript").find_program(target),
            argv = function (outfile)
                local outdir = path.directory(outfile)
                local argv = {path(sourcefile), "--outDir", path(outdir)}
                local lua_target = target:values("recudo.lang.typescript.target")
                if lua_target then
                    table.insert(argv, "--luaTarget")
                    table.insert(argv, tostring(lua_target))
                end
                local lua_lib_import = target:values("recudo.lang.typescript.lua_lib_import")
                if lua_lib_import then
                    table.insert(argv, "--luaLibImport")
                    table.insert(argv, tostring(lua_lib_import))
                end
                if target:values("recudo.lang.typescript.no_header") then
                    table.insert(argv, "--noHeader")
                end
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".ts", "typescript")
    end)
