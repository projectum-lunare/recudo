-- Projectum Lunare Recudo - Unified Build, Toolchain & Cross-Compilation Addon
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

set_project("recudo")
set_version("0.2.8")
set_xmakever("2.8.5")

includes("includes/recudo.lua")

target("test")
    set_kind("phony")
    set_default(false)
    add_tests("unit")
    on_test(function (target, opt)
        os.execv("xmake", {"l", "tests/run.lua"})
        return true
    end)
    on_run(function (target)
        os.execv("xmake", {"l", "tests/run.lua"})
    end)
