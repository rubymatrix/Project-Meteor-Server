/* Quick check of the built Lua library.
 *
 *   xlua_smoke <path to xlua library> <exports.txt> <smoke.lua>
 *
 * Loads the library the way the server does, checks it contains every function
 * the server's C# code calls (listed in exports.txt), then runs smoke.lua with it.
 * Exits with an error code if anything fails.
 */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
typedef HMODULE lib_t;
static lib_t lib_open(const char *p) { return LoadLibraryA(p); }
static void *lib_sym(lib_t l, const char *n) { return (void *)GetProcAddress(l, n); }
#else
#include <dlfcn.h>
typedef void *lib_t;
static lib_t lib_open(const char *p) { return dlopen(p, RTLD_NOW | RTLD_LOCAL); }
static void *lib_sym(lib_t l, const char *n) { return dlsym(l, n); }
#endif

typedef struct lua_State lua_State;
typedef lua_State *(*newstate_fn)(void);
typedef void (*state_fn)(lua_State *);
typedef int (*open_fn)(lua_State *);
typedef int (*loadbuffer_fn)(lua_State *, const char *, int, const char *);
typedef int (*pcall_fn)(lua_State *, int, int, int);
typedef const char *(*tolstring_fn)(lua_State *, int, size_t *);
typedef void (*pushint64_fn)(lua_State *, int64_t);
typedef int (*setglobal_fn)(lua_State *, const char *);
typedef int (*getlibversion_fn)(void);
typedef void (*pushnumber_fn)(lua_State *, double);
typedef void (*settop_fn)(lua_State *, int);
typedef int (*tointeger_fn)(lua_State *, int);
typedef uint32_t (*touint_fn)(lua_State *, int);

/* Numbers that must convert to C# int and uint the same way on every machine
 * (see the Meteor notes in xlua.c). */
struct conv_case { double in; int is_uint; int64_t want; };
static const struct conv_case conv_cases[] = {
    { -1.0,         1, 0 },
    { -0.5,         1, 0 },
    { 4294967296.0, 1, UINT32_MAX },
    { 3e9,          1, 3000000000u },
    { 3e9,          0, INT32_MAX },
    { -3e9,         0, INT32_MIN },
    { 2.7,          0, 2 },
    { -2.7,         0, -2 },
};

static char *read_file(const char *path, long *len)
{
    FILE *f = fopen(path, "rb");
    char *buf;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    *len = ftell(f);
    fseek(f, 0, SEEK_SET);
    buf = (char *)malloc((size_t)*len + 1);
    if (fread(buf, 1, (size_t)*len, f) != (size_t)*len) { fclose(f); free(buf); return NULL; }
    buf[*len] = '\0';
    fclose(f);
    return buf;
}

static int check_exports(lib_t lib, const char *path)
{
    long len;
    char *text = read_file(path, &len), *line;
    int found = 0, missing = 0;
    if (!text) { fprintf(stderr, "cannot read %s\n", path); return 1; }
    for (line = strtok(text, "\r\n"); line; line = strtok(NULL, "\r\n")) {
        if (!*line || *line == '#') continue;
        if (lib_sym(lib, line)) {
            found++;
        } else {
            fprintf(stderr, "missing export: %s\n", line);
            missing++;
        }
    }
    free(text);
    printf("exports: %d resolved, %d missing\n", found, missing);
    return missing != 0;
}

#define SYM(type, name) \
    type name = (type)lib_sym(lib, #name); \
    if (!name) { fprintf(stderr, "missing export: %s\n", #name); return 1; }

int main(int argc, char **argv)
{
    lib_t lib;
    long len;
    char *script;
    lua_State *L;
    int rc;

    if (argc != 4) {
        fprintf(stderr, "usage: %s <xlua library> <exports.txt> <smoke.lua>\n", argv[0]);
        return 2;
    }
    lib = lib_open(argv[1]);
    if (!lib) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
    if (check_exports(lib, argv[2])) return 1;

    {
        SYM(newstate_fn, luaL_newstate)
        SYM(state_fn, luaopen_xlua)
        SYM(open_fn, luaopen_i64lib)
        SYM(loadbuffer_fn, xluaL_loadbuffer)
        SYM(pcall_fn, lua_pcall)
        SYM(tolstring_fn, lua_tolstring)
        SYM(pushint64_fn, lua_pushint64)
        SYM(setglobal_fn, xlua_setglobal)
        SYM(state_fn, lua_close)
        SYM(getlibversion_fn, xlua_get_lib_version)
        SYM(pushnumber_fn, lua_pushnumber)
        SYM(settop_fn, lua_settop)
        SYM(tointeger_fn, xlua_tointeger)
        SYM(touint_fn, xlua_touint)

        printf("xlua lib version %d\n", xlua_get_lib_version());
        script = read_file(argv[3], &len);
        if (!script) { fprintf(stderr, "cannot read %s\n", argv[3]); return 1; }

        /* Start Lua the way the server's C# code does: the standard libraries,
         * then xLua's 64-bit integer support. */
        L = luaL_newstate();
        luaopen_xlua(L);
        luaopen_i64lib(L);
        lua_pushint64(L, INT64_C(1) << 40);
        xlua_setglobal(L, "big");

        rc = xluaL_loadbuffer(L, script, (int)len, "@smoke.lua");
        if (rc == 0) rc = lua_pcall(L, 0, 0, 0);
        if (rc != 0) {
            const char *err = lua_tolstring(L, -1, NULL);
            fprintf(stderr, "lua error: %s\n", err ? err : "(non-string error)");
        }
        if (rc == 0) {
            size_t i;
            for (i = 0; i < sizeof conv_cases / sizeof conv_cases[0]; i++) {
                const struct conv_case *c = &conv_cases[i];
                int64_t got;
                lua_pushnumber(L, c->in);
                got = c->is_uint ? (int64_t)xlua_touint(L, -1) : (int64_t)xlua_tointeger(L, -1);
                lua_settop(L, 0);
                if (got != c->want) {
                    fprintf(stderr, "%s(%.17g) = %lld, want %lld\n", c->is_uint ? "xlua_touint" : "xlua_tointeger",
                            c->in, (long long)got, (long long)c->want);
                    rc = 1;
                }
            }
            lua_pushnumber(L, NAN);
            if (xlua_tointeger(L, -1) != 0 || xlua_touint(L, -1) != 0) {
                fprintf(stderr, "NaN did not convert to 0\n");
                rc = 1;
            }
            lua_settop(L, 0);
            if (rc == 0) printf("integer conversions: ok\n");
        }
        lua_close(L);
        free(script);
    }
    if (rc != 0) return 1;
    printf("smoke: ok\n");
    return 0;
}
