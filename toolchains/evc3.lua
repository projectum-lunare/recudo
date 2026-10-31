-- Projectum Lunare Forge
-- Toolchain: Microsoft Embedded Visual C++ 3.0 (Windows CE) via wibo
-- Uses native Xmake rule: forge.evc3

includes(path.join(os.scriptdir(), "../modules/catalog.lua"))
local wince = get("wince")
local sdk_name = wince.sdk_name
local sdk_env = wince.sdk_env
_dismiss()

toolchain("evc3")
    set_kind("standalone")
    set_homepage("https://github.com/wine-mirror/wine")
    set_description("Microsoft Embedded Visual C++ 3.0 (Windows CE via wibo)")

    on_check(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local evc_dir = sdk.find(sdk_name, sdk_env, {must_exist = true})
        if not evc_dir or not os.isdir(evc_dir) then
            return false
        end

        local clarm = path.join(evc_dir, "bin/clarm.exe")
        local link = path.join(evc_dir, "bin/link.exe")
        if not (os.isfile(clarm) or os.isfile(link)) then
            return false
        end

        if os.host() == "windows" then
            return true
        end

        local wibo_bin = os.getenv("WIBO_BIN")
        if not wibo_bin then
            local wibo_dir = sdk.find("wibo", "WIBO_DIR", {must_exist = true})
            if wibo_dir then
                wibo_bin = path.join(wibo_dir, "bin/wibo")
            end
        end
        return wibo_bin and os.isexec(wibo_bin)
    end)

    on_load(function (toolchain)
        import("modules.sdk", {rootdir = path.join(os.scriptdir(), "..")})
        local evc_dir = sdk.find(sdk_name, sdk_env)
        local wibo_bin = os.getenv("WIBO_BIN")
        if not wibo_bin then
            local wibo_dir = sdk.find("wibo", "WIBO_DIR")
            if wibo_dir then
                wibo_bin = path.join(wibo_dir, "bin/wibo")
            end
        end

        if evc_dir then
            toolchain:add("envs", sdk_env, evc_dir)
        end
        if wibo_bin then
            toolchain:add("envs", "WIBO_BIN", wibo_bin)
        end
    end)
