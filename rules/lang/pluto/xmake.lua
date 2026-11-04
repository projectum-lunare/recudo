-- Projectum Lunare Recudo - Pluto Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.pluto")
    set_extensions(".pluto")

    on_load(function (target)
        import("lang.base").ensure_package(target, "pluto")
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "pluto",
            ext = ".pluto",
            program = import("lang.pluto").find_compiler(target),
            argv = function (outfile)
                local argv = {}
                if target:values("recudo.lang.pluto.compatibility") then
                    table.insert(argv, "-c")
                end
                if target:values("recudo.lang.pluto.strip") then
                    table.insert(argv, "-s")
                end
                table.insert(argv, "-o")
                table.insert(argv, path(outfile))
                table.insert(argv, path(sourcefile))
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".pluto", "pluto")
    end)
