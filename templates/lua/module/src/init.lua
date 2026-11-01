-- Module definition for ${TARGET_NAME}

local M = {
    _VERSION = "0.1.0"
}

function M.hello()
    return "Hello from " .. "${TARGET_NAME}" .. "!"
end

return M
