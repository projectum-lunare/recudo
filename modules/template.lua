-- Projectum Lunare Forge - Micro Template Engine
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- Zero-dependency, high-performance ERB-style template compiler for Lua.
-- Supports:
--   <%= expression %>  - Evaluates expression and outputs tostring(val)
--   <% lua code %>     - Arbitrary control flow (for, if, assignments, etc.)

local _load = (load ~= nil) and load or debug.global("load")
local _setmetatable = (setmetatable ~= nil) and setmetatable or debug.global("setmetatable")
local _g = (type(_G) == "table") and _G or debug.global()

-- Compile template string into a callable render function: fn(context) -> string
function compile(tmpl_str)
    assert(type(tmpl_str) == "string", "template must be a string")

    local buf = {"local _ctx = ...; local _out = {}\n"}
    local pos = 1

    while true do
        local s, e, is_eval, code = tmpl_str:find("<%%(=?)(.-)%%>", pos)
        if not s then
            local text = tmpl_str:sub(pos)
            if #text > 0 then
                table.insert(buf, "_out[#_out+1] = " .. string.format("%q", text) .. "\n")
            end
            break
        end

        local text = tmpl_str:sub(pos, s - 1)
        if #text > 0 then
            table.insert(buf, "_out[#_out+1] = " .. string.format("%q", text) .. "\n")
        end

        if is_eval == "=" then
            table.insert(buf, "_out[#_out+1] = tostring(" .. code .. ")\n")
        else
            table.insert(buf, code .. "\n")
        end

        pos = e + 1
    end

    table.insert(buf, "return table.concat(_out)")
    local code_str = table.concat(buf)

    return function(context)
        context = context or {}
        local env = _setmetatable({}, {
            __index = function(_, k)
                if context[k] ~= nil then
                    return context[k]
                end
                return _g[k]
            end
        })

        local fn, err = _load(code_str, "template", "t", env)
        if not fn then
            error("Template compilation failed: " .. tostring(err) .. "\nSource:\n" .. code_str)
        end
        return fn(context)
    end
end

-- Render a template string directly with context
function render(tmpl_str, context)
    local compiled_fn = compile(tmpl_str)
    return compiled_fn(context)
end

-- Render a template file from disk directly with context
function render_file(filepath, context)
    local content = io.readfile(filepath)
    if not content then
        error("Template file not found: " .. tostring(filepath))
    end
    return render(content, context)
end
