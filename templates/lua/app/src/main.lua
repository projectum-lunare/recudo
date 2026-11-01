-- Application entrypoint for ${TARGET_NAME}

local function main()
    print("Hello from " .. (_G._NAME or "${TARGET_NAME}") .. " powered by Forge!")
end

main()
