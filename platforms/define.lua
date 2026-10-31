-- Apply one catalog entry. xmake loads platforms/<id>/xmake.lua, so each
-- directory calls define_platform. The catalog itself cannot import() here.

includes(path.join(_FORGE_ROOT, "modules/catalog.lua"))

local function fill(entry)
    set_os(entry.os)
    set_hosts(table.unpack(entry.hosts))
    set_archs(table.unpack(entry.archs))
    for _, fmt in ipairs(entry.formats) do
        set_formats(fmt[1], fmt[2])
    end
    if entry.installdir then
        set_installdir(entry.installdir)
    end
    set_toolchains(entry.toolchain)
end

function define_platform(id)
    local entry = get(id)
    platform(entry.id)
    fill(entry)
    if entry.alias then
        platform(entry.alias)
        fill(entry)
    end
end
