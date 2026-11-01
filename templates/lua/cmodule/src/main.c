#include <lua.h>
#include <lauxlib.h>

static int l_hello(lua_State *L) {
    lua_pushstring(L, "Hello from native ${TARGET_NAME} module!");
    return 1;
}

static const struct luaL_Reg module_funcs[] = {
    {"hello", l_hello},
    {NULL, NULL}
};

int luaopen_${TARGET_NAME}(lua_State *L) {
#if LUA_VERSION_NUM >= 502
    luaL_newlib(L, module_funcs);
#else
    lua_newtable(L);
    luaL_register(L, NULL, module_funcs);
#endif
    return 1;
}
