-- Module names and the relative paths require() searches.
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0

-- luaopen_foo_bar from module name foo.bar
function open_symbol(modname)
    return "luaopen_" .. tostring(modname):gsub("[^%w]", "_")
end

-- Linker name. Dots are not valid in archive names.
function link_name(modname)
    return (tostring(modname):gsub("[^%w]", "_"))
end

function module_parts(modname)
    local parts = {}
    for part in tostring(modname):gmatch("[^%.]+") do
        table.insert(parts, part)
    end
    if #parts == 0 then
        table.insert(parts, "main")
    end
    return parts
end

-- "1.2.3" or "v5.4.6" -> "1.2" / "5.4". Anything else is left unset.
function lua_version_string(value)
    if value == nil then
        return nil
    end
    local text = tostring(value):gsub("^v", "")
    local major, minor = text:match("^(%d+)%.(%d+)")
    if major then
        return major .. "." .. minor
    end
end

-- foo.bar + hello.lua -> foo/bar.lua. An init.lua source keeps the init name.
function module_lua_relpath(modname, source)
    local parts = module_parts(modname)
    local base = path.filename(source or "")
    if base == "init.lua" then
        return table.concat(parts, "/") .. "/init.lua"
    end
    if #parts == 1 then
        return parts[1] .. ".lua"
    end
    local leaf = parts[#parts]
    local head = {}
    for i = 1, #parts - 1 do
        table.insert(head, parts[i])
    end
    return table.concat(head, "/") .. "/" .. leaf .. ".lua"
end

-- forge.native + so -> forge/native.so
function module_c_relpath(modname, ext)
    local parts = module_parts(modname)
    local leaf = parts[#parts]
    ext = ext:gsub("^%.", "")
    if #parts == 1 then
        return leaf .. "." .. ext
    end
    local head = {}
    for i = 1, #parts - 1 do
        table.insert(head, parts[i])
    end
    return table.concat(head, "/") .. "/" .. leaf .. "." .. ext
end
