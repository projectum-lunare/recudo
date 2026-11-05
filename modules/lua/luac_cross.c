/*
 * Projectum Lunare Recudo - Target-Aware Lua Bytecode Cross-Compiler
 * Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

#define ldump_c
#define LUA_CORE

#include "lprefix.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <stddef.h>
#if defined(_WIN32)
#  include <process.h>
#else
#  include <unistd.h>
#endif

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "lapi.h"
#include "lgc.h"
#include "lobject.h"
#include "lstate.h"
#include "ltable.h"
#include "lundump.h"

typedef struct {
    lua_State *L;
    FILE *out;
    size_t offset;
    int strip;
    int status;
    Table *h;
    lua_Unsigned nstr;
    /* Target profile */
    int target_endian; /* 0 = Little Endian (LE), 1 = Big Endian (BE) */
    int target_32bit;  /* 0 = 64-bit Lua, 1 = 32-bit Lua (LUA_32BITS) */
} DumpState;

/*
 * Byte-swapping helpers
 */
static unsigned short swap16(unsigned short v)
{
    return (unsigned short)((v >> 8) | (v << 8));
}

static unsigned int swap32(unsigned int v)
{
    return ((v >> 24) & 0x000000ffU) | ((v >> 8) & 0x0000ff00U) | ((v << 8) & 0x00ff0000U) |
           ((v << 24) & 0xff000000U);
}

static unsigned long long swap64(unsigned long long v)
{
    return ((unsigned long long)swap32((unsigned int)(v & 0xffffffffU)) << 32) |
           (unsigned long long)swap32((unsigned int)((v >> 32) & 0xffffffffU));
}

static float swap_float(float f)
{
    union {
        float f;
        unsigned int u;
    } val;
    val.f = f;
    val.u = swap32(val.u);
    return val.f;
}

static double swap_double(double d)
{
    union {
        double d;
        unsigned long long u;
    } val;
    val.d = d;
    val.u = swap64(val.u);
    return val.d;
}

static void dumpBlock(DumpState *D, const void *b, size_t size)
{
    if (D->status == 0 && size > 0) {
        if (fwrite(b, 1, size, D->out) != size) {
            D->status = 1;
        }
        D->offset += size;
    }
}

static void dumpAlign(DumpState *D, unsigned align)
{
    unsigned padding = align - (unsigned)(D->offset % align);
    if (padding < align) {
        static const unsigned char paddingContent[8] = {0};
        dumpBlock(D, paddingContent, padding);
    }
}

static void dumpByte(DumpState *D, int y)
{
    lu_byte x = (lu_byte)y;
    dumpBlock(D, &x, 1);
}

#define DIBS ((l_numbits(lua_Unsigned) + 6) / 7)

static void dumpVarint(DumpState *D, lua_Unsigned x)
{
    lu_byte buff[DIBS];
    unsigned n = 1;
    buff[DIBS - 1] = x & 0x7f;
    while ((x >>= 7) != 0)
        buff[DIBS - (++n)] = (lu_byte)((x & 0x7f) | 0x80);
    dumpBlock(D, buff + DIBS - n, n);
}

static void dumpSize(DumpState *D, size_t sz)
{
    dumpVarint(D, (lua_Unsigned)sz);
}

static void dumpInt(DumpState *D, int x)
{
    dumpVarint(D, (lua_Unsigned)x);
}

static void dumpNumber(DumpState *D, lua_Number x)
{
    if (D->target_32bit) {
        float f = (float)x;
        if (D->target_endian == 1) {
            f = swap_float(f);
        }
        dumpBlock(D, &f, sizeof(float));
    } else {
        double d = (double)x;
        if (D->target_endian == 1) {
            d = swap_double(d);
        }
        dumpBlock(D, &d, sizeof(double));
    }
}

static void dumpInteger(DumpState *D, lua_Integer x)
{
    lua_Unsigned cx = (x >= 0) ? 2u * l_castS2U(x) : (2u * ~l_castS2U(x)) + 1;
    dumpVarint(D, cx);
}

static void dumpString(DumpState *D, TString *ts)
{
    if (ts == NULL) {
        dumpVarint(D, 0);
        dumpVarint(D, 0);
    } else {
        TValue idx;
        int tag = luaH_getstr(D->h, ts, &idx);
        if (!tagisempty(tag)) {
            dumpVarint(D, 0);
            dumpVarint(D, l_castS2U(ivalue(&idx)));
        } else {
            TValue key, value;
            size_t size;
            const char *s = getlstr(ts, size);
            dumpSize(D, size + 1);
            dumpBlock(D, s, size + 1);
            D->nstr++;
            setsvalue(D->L, &key, ts);
            setivalue(&value, l_castU2S(D->nstr));
            luaH_set(D->L, D->h, &key, &value);
        }
    }
}

static void dumpCode(DumpState *D, const Proto *f)
{
    int i;
    dumpInt(D, f->sizecode);
    dumpAlign(D, sizeof(Instruction));
    if (D->target_endian == 1) {
        for (i = 0; i < f->sizecode; i++) {
            unsigned int inst = swap32((unsigned int)f->code[i]);
            dumpBlock(D, &inst, sizeof(Instruction));
        }
    } else {
        dumpBlock(D, f->code, (size_t)f->sizecode * sizeof(Instruction));
    }
}

static void dumpFunction(DumpState *D, const Proto *f);

static void dumpConstants(DumpState *D, const Proto *f)
{
    int i;
    int n = f->sizek;
    dumpInt(D, n);
    for (i = 0; i < n; i++) {
        const TValue *o = &f->k[i];
#if LUA_VERSION_NUM >= 505
        int tt = ttypetag(o);
#else
        int tt = ttype(o);
#endif
        dumpByte(D, tt);
        switch (tt) {
        case LUA_VNIL:
        case LUA_VFALSE:
        case LUA_VTRUE:
            break;
        case LUA_VNUMFLT:
            dumpNumber(D, fltvalue(o));
            break;
        case LUA_VNUMINT:
            dumpInteger(D, ivalue(o));
            break;
        case LUA_VSHRSTR:
        case LUA_VLNGSTR:
            dumpString(D, tsvalue(o));
            break;
        default:
            lua_assert(0);
        }
    }
}

static void dumpProtos(DumpState *D, const Proto *f)
{
    int i;
    int n = f->sizep;
    dumpInt(D, n);
    for (i = 0; i < n; i++) {
        dumpFunction(D, f->p[i]);
    }
}

static void dumpUpvalues(DumpState *D, const Proto *f)
{
    int i;
    int n = f->sizeupvalues;
    dumpInt(D, n);
    for (i = 0; i < n; i++) {
        dumpByte(D, f->upvalues[i].instack);
        dumpByte(D, f->upvalues[i].idx);
        dumpByte(D, f->upvalues[i].kind);
    }
}

static void dumpDebug(DumpState *D, const Proto *f)
{
    int i, n;
    n = (D->strip) ? 0 : f->sizelineinfo;
    dumpInt(D, n);
    if (f->lineinfo != NULL && n > 0) {
        dumpBlock(D, f->lineinfo, (size_t)n * sizeof(f->lineinfo[0]));
    }
    n = (D->strip) ? 0 : f->sizeabslineinfo;
    dumpInt(D, n);
    if (n > 0) {
        dumpAlign(D, sizeof(int));
        if (D->target_endian == 1) {
            for (i = 0; i < n; i++) {
                int pc = swap32((unsigned int)f->abslineinfo[i].pc);
                int line = swap32((unsigned int)f->abslineinfo[i].line);
                dumpBlock(D, &pc, sizeof(int));
                dumpBlock(D, &line, sizeof(int));
            }
        } else {
            dumpBlock(D, f->abslineinfo, (size_t)n * sizeof(f->abslineinfo[0]));
        }
    }
    n = (D->strip) ? 0 : f->sizelocvars;
    dumpInt(D, n);
    for (i = 0; i < n; i++) {
        dumpString(D, f->locvars[i].varname);
        dumpInt(D, f->locvars[i].startpc);
        dumpInt(D, f->locvars[i].endpc);
    }
    n = (D->strip) ? 0 : f->sizeupvalues;
    dumpInt(D, n);
    for (i = 0; i < n; i++) {
        dumpString(D, f->upvalues[i].name);
    }
}

static void dumpFunction(DumpState *D, const Proto *f)
{
#if LUA_VERSION_NUM >= 505
    dumpInt(D, f->linedefined);
    dumpInt(D, f->lastlinedefined);
    dumpByte(D, f->numparams);
    dumpByte(D, f->flag);
    dumpByte(D, f->maxstacksize);
#else
    dumpByte(D, f->numparams);
    dumpByte(D, f->is_vararg);
    dumpByte(D, f->maxstacksize);
#endif
    dumpCode(D, f);
    dumpConstants(D, f);
    dumpUpvalues(D, f);
    dumpProtos(D, f);
    dumpString(D, D->strip ? NULL : f->source);
    dumpDebug(D, f);
}

static void dumpHeader(DumpState *D)
{
    dumpBlock(D, LUA_SIGNATURE, sizeof(LUA_SIGNATURE) - 1);
    dumpByte(D, LUAC_VERSION);
    dumpByte(D, LUAC_FORMAT);
    dumpBlock(D, LUAC_DATA, sizeof(LUAC_DATA) - 1);

#if LUA_VERSION_NUM >= 505
    /* Lua 5.5+: dumpNumInfo(int, LUAC_INT) */
    dumpByte(D, sizeof(int));
    if (D->target_endian == 1) {
        int v = (int)swap32((unsigned int)(int)LUAC_INT);
        dumpBlock(D, &v, sizeof(int));
    } else {
        int v = (int)LUAC_INT;
        dumpBlock(D, &v, sizeof(int));
    }
#endif

    /* Target instruction size */
    dumpByte(D, sizeof(Instruction));
#if LUA_VERSION_NUM >= 505
    if (D->target_endian == 1) {
        unsigned int inst = swap32((unsigned int)LUAC_INST);
        dumpBlock(D, &inst, sizeof(Instruction));
    } else {
        unsigned int inst = (unsigned int)LUAC_INST;
        dumpBlock(D, &inst, sizeof(Instruction));
    }
#endif

    /* Target integer size and test integer value */
    if (D->target_32bit) {
        dumpByte(D, 4); /* sizeof(int) */
        if (D->target_endian == 1) {
            unsigned int test_int = swap32((unsigned int)(int)LUAC_INT);
            dumpBlock(D, &test_int, 4);
        } else {
            unsigned int test_int = (unsigned int)(int)LUAC_INT;
            dumpBlock(D, &test_int, 4);
        }
    } else {
        dumpByte(D, 8); /* sizeof(long long) */
        if (D->target_endian == 1) {
            unsigned long long test_int = swap64((unsigned long long)(lua_Integer)LUAC_INT);
            dumpBlock(D, &test_int, 8);
        } else {
            unsigned long long test_int = (unsigned long long)(lua_Integer)LUAC_INT;
            dumpBlock(D, &test_int, 8);
        }
    }

    /* Target float size and test float value */
    if (D->target_32bit) {
        dumpByte(D, 4); /* sizeof(float) */
        float test_num = (float)cast_num(-370.5);
        if (D->target_endian == 1) {
            test_num = swap_float(test_num);
        }
        dumpBlock(D, &test_num, 4);
    } else {
        dumpByte(D, 8); /* sizeof(double) */
        double test_num = (double)cast_num(-370.5);
        if (D->target_endian == 1) {
            test_num = swap_double(test_num);
        }
        dumpBlock(D, &test_num, 8);
    }
}

int recudo_cross_dump(lua_State *L, const Proto *f, FILE *out, int endian, int bits, int strip)
{
    DumpState D;
    D.L = L;
    D.out = out;
    D.offset = 0;
    D.strip = strip;
    D.status = 0;
    D.nstr = 0;
    D.target_endian = endian;
    D.target_32bit = (bits == 32) ? 1 : 0;
    D.h = luaH_new(L);
    sethvalue2s(L, L->top.p, D.h);
    L->top.p++;

    dumpHeader(&D);
    dumpByte(&D, f->sizeupvalues);
    dumpFunction(&D, f);

    L->top.p--;
    return D.status;
}

static void print_usage(const char *prog)
{
    fprintf(stderr, "Usage: %s [options] <input.lua>\n", prog);
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -o <path>          Output file destination (default: stdout)\n");
    fprintf(stderr, "  --endian <le|be>   Target endianness: le (little, default) or be (big)\n");
    fprintf(stderr, "  --bits <32|64>     Target Lua word size: 32 (LUA_32BITS) or 64 (default)\n");
    fprintf(stderr, "  --c-array <ident>  Output as C array definition with identifier <ident>\n");
    fprintf(stderr, "  -s, --strip        Strip debug information (default: enabled)\n");
    fprintf(stderr, "  -g, --no-strip     Preserve debug line information\n");
    fprintf(stderr, "  -h, --help         Show this help information\n");
}

int main(int argc, char **argv)
{
    const char *infile = NULL;
    const char *outfile = NULL;
    const char *c_ident = NULL;
    int endian = 0; /* 0 = LE, 1 = BE */
    int bits = 64;  /* 64 or 32 */
    int strip = 1;  /* strip by default */
    int i;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            outfile = argv[++i];
        } else if (strcmp(argv[i], "--endian") == 0 && i + 1 < argc) {
            const char *val = argv[++i];
            if (strcmp(val, "be") == 0 || strcmp(val, "big") == 0)
                endian = 1;
            else if (strcmp(val, "le") == 0 || strcmp(val, "little") == 0)
                endian = 0;
            else {
                fprintf(stderr, "Error: Unknown endianness '%s' (expected 'le' or 'be')\n", val);
                return 1;
            }
        } else if (strcmp(argv[i], "--bits") == 0 && i + 1 < argc) {
            bits = atoi(argv[++i]);
            if (bits != 32 && bits != 64) {
                fprintf(stderr, "Error: Invalid bitness %d (expected 32 or 64)\n", bits);
                return 1;
            }
        } else if (strcmp(argv[i], "--c-array") == 0 && i + 1 < argc) {
            c_ident = argv[++i];
        } else if (strcmp(argv[i], "-s") == 0 || strcmp(argv[i], "--strip") == 0) {
            strip = 1;
        } else if (strcmp(argv[i], "-g") == 0 || strcmp(argv[i], "--no-strip") == 0) {
            strip = 0;
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        } else if (argv[i][0] != '-') {
            infile = argv[i];
        } else {
            fprintf(stderr, "Error: Unknown option '%s'\n", argv[i]);
            print_usage(argv[0]);
            return 1;
        }
    }

    if (!infile) {
        fprintf(stderr, "Error: No input Lua file specified.\n");
        print_usage(argv[0]);
        return 1;
    }

    lua_State *L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Error: Failed to initialize Lua state.\n");
        return 1;
    }
    /* Base library is sufficient for parsing */
    luaL_requiref(L, "_G", luaopen_base, 1);
    lua_pop(L, 1);

    if (luaL_loadfile(L, infile) != LUA_OK) {
        fprintf(stderr, "Error loading '%s': %s\n", infile, lua_tostring(L, -1));
        lua_close(L);
        return 1;
    }

    const Proto *p = clLvalue(s2v(L->top.p - 1))->p;

    FILE *out = stdout;
    char temp_bin_path[256];
    int use_temp = 0;

    if (c_ident) {
        /* If emitting C array, dump to a temp buffer or file first */
#if defined(_WIN32)
        snprintf(temp_bin_path, sizeof(temp_bin_path), "%s\\luac_cross_%d.tmp", getenv("TEMP") ? getenv("TEMP") : ".", (int)_getpid());
#else
        snprintf(temp_bin_path, sizeof(temp_bin_path), "/tmp/luac_cross_%d.tmp", (int)getpid());
#endif
        out = fopen(temp_bin_path, "wb");
        if (!out) {
            fprintf(stderr, "Error: Failed to create temporary file '%s'\n", temp_bin_path);
            lua_close(L);
            return 1;
        }
        use_temp = 1;
    } else if (outfile && strcmp(outfile, "-") != 0) {
        out = fopen(outfile, "wb");
        if (!out) {
            fprintf(stderr, "Error: Failed to open '%s' for writing\n", outfile);
            lua_close(L);
            return 1;
        }
    }

    int status = recudo_cross_dump(L, p, out, endian, bits, strip);
    if (status != 0) {
        fprintf(stderr, "Error: Bytecode dump failed for '%s'\n", infile);
        if (out != stdout)
            fclose(out);
        if (use_temp)
            remove(temp_bin_path);
        lua_close(L);
        return 1;
    }

    if (use_temp) {
        fclose(out);
        /* Reopen temp binary to read bytes and format into C array */
        FILE *bin_in = fopen(temp_bin_path, "rb");
        if (!bin_in) {
            fprintf(stderr, "Error: Failed to read temp dump '%s'\n", temp_bin_path);
            remove(temp_bin_path);
            lua_close(L);
            return 1;
        }

        FILE *c_out = stdout;
        if (outfile && strcmp(outfile, "-") != 0) {
            c_out = fopen(outfile, "w");
            if (!c_out) {
                fprintf(stderr, "Error: Failed to open '%s' for writing C array\n", outfile);
                fclose(bin_in);
                remove(temp_bin_path);
                lua_close(L);
                return 1;
            }
        }

        unsigned char buf[16];
        size_t nread;
        size_t b;
        int first_line = 1;

        fprintf(c_out, "static const unsigned char %s[] = {\n", c_ident);
        while ((nread = fread(buf, 1, sizeof(buf), bin_in)) > 0) {
            if (!first_line)
                fprintf(c_out, ",\n");
            first_line = 0;
            fprintf(c_out, "    ");
            for (b = 0; b < nread; b++) {
                if (b > 0)
                    fprintf(c_out, ", ");
                fprintf(c_out, "0x%02x", buf[b]);
            }
        }
        fprintf(c_out, "\n};\n");

        fclose(bin_in);
        remove(temp_bin_path);
        if (c_out != stdout)
            fclose(c_out);
    } else if (out != stdout) {
        fclose(out);
    }

    lua_close(L);
    return 0;
}
