-- xmake loads platforms/<id>/xmake.lua. The description is modules/catalog.lua.
-- platforms/dragonfly/xmake.lua is the alias xmake f -p dragonfly loads.
_FORGE_ROOT = path.normalize(path.join(os.scriptdir(), "../.."))
includes(path.join(_FORGE_ROOT, "platforms/define.lua"))
define_platform("dragonflybsd")
