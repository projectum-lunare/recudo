-- Projectum Lunare Forge - Unified Build, Toolchain & Cross-Compilation Addon
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

set_project("forge")
set_version("0.1.0")

includes("includes/forge.lua")

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
