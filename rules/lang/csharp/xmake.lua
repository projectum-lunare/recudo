-- Projectum Lunare Recudo - C# Language Rule (CSharp.lua)
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.csharp")
    set_extensions(".cs")

    on_load(function (target)
        import("lang.base").ensure_package(target, "csharp-lua")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "csharp",
            ext = ".cs",
            program = import("lang.csharp").find_program(target),
            argv = function (outfile)
                local outdir = path.directory(outfile)
                local argv = {"-s", path(sourcefile), "-d", path(outdir)}
                local libs = target:values("recudo.lang.csharp.lib")
                if libs then
                    for _, lib in ipairs(table.wrap(libs)) do
                        table.insert(argv, "-l")
                        table.insert(argv, tostring(lib))
                    end
                end
                if target:values("recudo.lang.csharp.meta") then
                    table.insert(argv, "-meta")
                end
                if target:values("recudo.lang.csharp.classic") then
                    table.insert(argv, "-c")
                end
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".cs", "csharp")
    end)
