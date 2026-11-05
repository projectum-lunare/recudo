-- Projectum Lunare Recudo - Pure C Link Toolchain
-- Copyright (C) 2026 Gustavo Veiga <gustavo.veiga@outlook.com.br>
-- Mozilla Public License Version 2.0
--
-- The xmake gcc toolchain defaults the shared-library linker (sh) to g++,
-- which injects -lstdc++ and records libstdc++.so.6 as NEEDED even for
-- pure C objects. This toolchain keeps the same compiler family but links
-- with the C driver, so C-only targets do not drag the C++ runtime.
--
-- Scope: host platforms with gcc/clang on PATH. Cross toolchains (evc3,
-- watcom, vbcc, atarist) define their own linkers and must not use this.

toolchain("recudo-c")
    set_kind("standalone")
    set_homepage("https://github.com/projectum-lunare/recudo")
    set_description("C-only link drivers (no C++ runtime dependency)")
    on_check(function (toolchain)
        return true
    end)
    set_toolset("cc", "gcc", "clang")
    set_toolset("cxx", "g++", "clang++")
    set_toolset("sh", "gcc", "clang")
    set_toolset("ld", "gcc", "clang")
    set_toolset("ar", "ar", "llvm-ar")
toolchain_end()
