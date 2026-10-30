#include "lua.h"
#include "lauxlib.h"

#if defined(_WIN32)
#  define FORGE_EXPORT __declspec(dllexport)
#else
#  define FORGE_EXPORT
#endif

FORGE_EXPORT int luaopen_forge_native(lua_State *L) {
    lua_pushinteger(L, 7);
    return 1;
}
