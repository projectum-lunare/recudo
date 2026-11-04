-- Projectum Lunare Recudo - YueScript Language Rule
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

rule("recudo.lang.yuescript")
    set_extensions(".yue")

    on_load(function (target)
        import("lang.base").ensure_package(target, "yuescript", {"yuescript", "yue"})
    end)

    before_buildcmd_file(function (target, batchcmds, sourcefile, opt)
        import("lang.base").build_transpiled(target, batchcmds, sourcefile, opt, {
            lang = "yuescript",
            ext = ".yue",
            program = import("lang.yuescript").find_program(target),
            argv = function (outfile)
                local argv = {}
                local yue_target = target:values("recudo.lang.yuescript.target")
                if yue_target then
                    table.insert(argv, "--target")
                    table.insert(argv, tostring(yue_target))
                end
                if target:values("recudo.lang.yuescript.minify") then
                    table.insert(argv, "-m")
                end
                table.insert(argv, "-o")
                table.insert(argv, path(outfile))
                table.insert(argv, path(sourcefile))
                return argv
            end
        })
    end)

    after_install(function (target)
        import("lang.base").install_transpiled(target, ".yue", "yuescript")
    end)
