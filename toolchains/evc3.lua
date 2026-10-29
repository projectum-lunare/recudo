-- solo - Physical I/O, System Foundations & Hardware Abstractions
-- Toolchain: Microsoft Embedded Visual C++ 3.0 (Windows CE) via wibo
-- Uses native Xmake rule: vintage.evc3

toolchain("evc3")
    set_kind("standalone")
    set_homepage("https://github.com/wine-mirror/wine")
    set_description("Microsoft Embedded Visual C++ 3.0 (Windows CE via wibo)")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local evc_dir = sdk.find("evc3", "EVC3_DIR")
        local wibo_bin = os.getenv("WIBO_BIN") or path.join(sdk.find("wibo", "WIBO_DIR"), "bin/wibo")
        return evc_dir and os.isdir(evc_dir) and os.isexec(wibo_bin)
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local evc_dir = sdk.find("evc3", "EVC3_DIR")
        toolchain:add("envs", "EVC3_DIR", evc_dir)
    end)
