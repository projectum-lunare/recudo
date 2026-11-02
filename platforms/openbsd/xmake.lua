-- xmake loads platforms/<id>/xmake.lua. The description is modules/catalog.lua.
_RECUDO_ROOT = path.normalize(path.join(os.scriptdir(), "../.."))
includes(path.join(_RECUDO_ROOT, "platforms/define.lua"))
define_platform("openbsd")
