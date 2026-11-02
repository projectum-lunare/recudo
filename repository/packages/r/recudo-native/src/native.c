#include "lua.h"
#include "lauxlib.h"

#if defined(_WIN32)
#  define RECUDO_EXPORT __declspec(dllexport)
#else
#  define RECUDO_EXPORT
#endif

RECUDO_EXPORT int luaopen_recudo_native(lua_State *L) {
    lua_pushinteger(L, 7);
    return 1;
}
