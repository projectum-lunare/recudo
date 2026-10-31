-- xmake loads platforms/<id>/xmake.lua. The description is modules/catalog.lua.
_FORGE_ROOT = path.normalize(path.join(os.scriptdir(), "../.."))
includes(path.join(_FORGE_ROOT, "platforms/define.lua"))
define_platform("openbsd")
