-- Projectum Lunare Forge - Lua Build Rules & Subsystem
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- ==============================================================================
-- 2. Rule: forge.lua.bin
-- Install a Lua program into bin/. The script keeps its shebang. Unix marks it
-- executable. Windows also gets a .cmd launcher that calls lua.
-- ==============================================================================
rule("forge.lua.bin")
    set_extensions(".lua")

    on_load(function (target)
        target:set("kind", "phony")
        -- A program such as src/bin/luacov has no extension, so the file rule
        -- would otherwise reject it as an unknown source.
        for _, sourcefile in ipairs(table.wrap(target:get("files"))) do
            target:fileconfig_set(sourcefile, {rules = "forge.lua.bin"})
        end
    end)

    after_install(function (target)
        local installdir = target:installdir()
        if not installdir then
            return
        end
        local bindir = path.join(installdir, "bin")
        local root = os.projectdir()
        local seen = {}
        for _, sourcefile in ipairs(table.wrap(target:get("files"))) do
            local src = path.is_absolute(sourcefile) and sourcefile or path.join(root, sourcefile)
            if os.isfile(src) then
                local name = path.filename(src)
                if name:endswith(".lua") then
                    name = name:sub(1, -5)
                end
                if not seen[name] then
                    seen[name] = true
                    os.mkdir(bindir)
                    local dest = path.join(bindir, name)
                    os.cp(src, dest)
                    if target:is_plat("windows") then
                        io.writefile(dest .. ".cmd", "@echo off\r\nlua \"%~dp0\\" .. name .. "\" %*\r\n")
                    else
                        try { function () os.runv("chmod", {"+x", dest}) end }
                    end
                end
            end
        end
    end)

