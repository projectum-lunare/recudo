-- Projectum Lunare Recudo
-- Rule: Microsoft Embedded Visual C++ 3.0 via wibo (Windows CE)
-- Native Xmake batchcmds execution (no external shell/python wrappers)

local function collect_target_values(target, name)
    local results = {}
    local values = target:get_from(name, "*")
    if values then
        for _, v in ipairs(table.wrap(values)) do
            if type(v) == "table" then
                for _, item in ipairs(v) do
                    table.insert(results, item)
                end
            elseif v ~= nil then
                table.insert(results, v)
            end
        end
    end
    return results
end

local function to_wibo_path(p)
    if p and p:startswith("/") then
        return "Z:" .. p
    end
    return p
end

local function setup_evc3_rule(rule_name)
    rule(rule_name)
        set_extensions(".c", ".cc", ".cpp", ".cxx")

        on_load(function (target)
            if target:is_static() and not target:get("filename") then
                target:set("filename", target:basename() .. ".lib")
            end

            local root = path.join(os.scriptdir(), "../../..")
            import("modules.sdk", {rootdir = root})
            local entry = import("catalog", {rootdir = path.join(root, "modules")}).get("wince")
            local s = sdk.find(entry.sdk_name, entry.sdk_env)
            target:data_set("evc3.sdk", s)

            local wibo_bin = os.getenv("WIBO_BIN")
            if not wibo_bin then
                local wibo_dir = sdk.find("wibo", "WIBO_DIR")
                if wibo_dir then
                    wibo_bin = path.join(wibo_dir, "bin/wibo")
                end
            end
            target:data_set("evc3.wibo", wibo_bin)

            local arch = target:data("evc3.arch") or get_config("arch") or "arm"
            target:data_set("evc3.arch", arch)

            -- WinCE is exclusively 32-bit little-endian across all supported dies
            target:values_set("recudo.lua.bundle.endian", "le")
            target:values_set("recudo.lua.bundle.bits", 32)

            local compat_mode = target:values("recudo.toolchain.evc3.compat") or target:values("recudo.evc3.compat")
            if compat_mode ~= false then
                target:data_set("evc3.compat", true)
                local compat_dir = path.join(os.scriptdir(), "compat")
                target:data_set("evc3.compat_dir", compat_dir)
                target:add("includedirs", path.join(compat_dir, "include"), {order = "before"})
                if target:is_binary() or target:is_shared() then
                    target:add("files", path.join(compat_dir, "crt.c"))
                    if target:is_binary() and not target:values("recudo.toolchain.evc3.entry") and not target:values("recudo.toolchain.evc3.no_main_bridge") then
                        target:add("files", path.join(compat_dir, "main_bridge.c"))
                    end
                end
            end
        end)

        on_buildcmd_file(function (target, batchcmds, sourcefile, opt)
            local s = target:data("evc3.sdk")
            local wibo = target:data("evc3.wibo")
            local arch = target:data("evc3.arch") or "arm"

            local function scan_evc3_includes(filepath, searchdirs, visited, results)
                visited = visited or {}
                results = results or {}
                if visited[filepath] or not os.isfile(filepath) then return results end
                visited[filepath] = true
                local content = io.readfile(filepath)
                if not content then return results end
                for _, line in ipairs(content:split("\n", {plain = true})) do
                    local inc = line:match('^%s*#%s*include%s*["<]([^">]+)[">]')
                    if inc then
                        local candidate = path.join(path.directory(filepath), inc)
                        if os.isfile(candidate) then
                            table.insert(results, candidate)
                            scan_evc3_includes(candidate, searchdirs, visited, results)
                        else
                            for _, d in ipairs(searchdirs) do
                                candidate = path.join(d, inc)
                                if os.isfile(candidate) then
                                    table.insert(results, candidate)
                                    scan_evc3_includes(candidate, searchdirs, visited, results)
                                    break
                                end
                            end
                        end
                    end
                end
                return results
            end

            local comp_name = "clarm.exe"
            local arch_defs = {"_ARM_", "ARM"}
            local arch_flags = {}
            if arch == "mips" then
                comp_name = "clmips.exe"
                arch_defs = {"_MIPS_", "MIPS"}
            elseif arch == "ppc" then
                comp_name = "clppc.exe"
                arch_defs = {"_PPC_", "PPC"}
            elseif arch == "sh3" then
                comp_name = "shcl.exe"
                arch_defs = {"_SH3_", "SH3", "SHx"}
                arch_flags = {"/Qsh3"}
            elseif arch == "sh4" then
                comp_name = "shcl.exe"
                arch_defs = {"_SH4_", "SH4", "SHx"}
                arch_flags = {"/Qsh4"}
            elseif arch == "x86" then
                comp_name = "cl.exe"
                arch_defs = {"_X86_", "x86", "_WIN32_WCE_EMULATION"}
            end

            local cl_exe = path.join(s, "bin", comp_name)
            local objfile = target:objectfile(sourcefile)

            -- Deduplicated registration into target:objectfiles()
            local current_objs = target:objectfiles()
            if current_objs and not table.contains(current_objs, objfile) then
                table.insert(current_objs, objfile)
            end

            local is_cxx = sourcefile:endswith(".cpp") or sourcefile:endswith(".cc") or sourcefile:endswith(".cxx")
            local envs = {
                INCLUDE = path.join(s, "include"),
                LIB = path.join(s, "lib", arch)
            }

            local argv = {
                cl_exe,
                "/nologo",
                "/c"
            }

            if is_cxx then
                table.insert(argv, "/TP")
            else
                table.insert(argv, "/TC")
            end

            -- Optimization mapping
            local opt_level = target:get("optimize")
            if not opt_level then
                opt_level = (is_mode and is_mode("debug")) and "none" or "fast"
            end
            if opt_level == "none" then
                table.insert(argv, "/Od")
            elseif opt_level == "smallest" then
                table.insert(argv, "/O1")
            else
                table.insert(argv, "/O2")
            end

            -- Debug symbols
            if target:get("symbols") or (is_mode and is_mode("debug")) then
                table.insert(argv, "/Z7")
            end

            -- Warnings
            local warnings = target:get("warnings")
            if warnings == "none" then
                table.insert(argv, "/w")
            elseif warnings == "all" or warnings == "everything" then
                table.insert(argv, "/W4")
            elseif warnings == "error" then
                table.insert(argv, "/WX")
            else
                table.insert(argv, "/W3")
            end

            -- Built-in CE defines
            table.insert(argv, "/DUNICODE")
            table.insert(argv, "/D_UNICODE")
            table.insert(argv, "/DUNDER_CE=300")
            table.insert(argv, "/D_WIN32_WCE=300")

            for _, d in ipairs(arch_defs) do
                table.insert(argv, "/D" .. d)
            end

            for _, f in ipairs(arch_flags) do
                table.insert(argv, f)
            end

            -- Target defines
            for _, def in ipairs(collect_target_values(target, "defines")) do
                table.insert(argv, "/D" .. def)
            end

            -- Target includedirs (user and compat headers precede SDK headers)
            local incdirs = table.join(collect_target_values(target, "includedirs"), collect_target_values(target, "sysincludedirs"))
            for _, inc in ipairs(incdirs) do
                table.insert(argv, "/I" .. to_wibo_path(path.absolute(inc)))
            end

            -- SDK system headers
            table.insert(argv, "/I" .. to_wibo_path(path.join(s, "include")))

            -- Target cxflags, cflags, cxxflags
            for _, flag in ipairs(table.wrap(target:get("cxflags"))) do
                table.insert(argv, flag)
            end
            if is_cxx then
                for _, flag in ipairs(table.wrap(target:get("cxxflags"))) do
                    table.insert(argv, flag)
                end
            else
                for _, flag in ipairs(table.wrap(target:get("cflags"))) do
                    table.insert(argv, flag)
                end
            end

            if target:data("evc3.compat") then
                table.insert(argv, "/FIwince_c89.h")
            end

            table.insert(argv, "/Fo" .. to_wibo_path(path.absolute(objfile)))
            table.insert(argv, to_wibo_path(path.absolute(sourcefile)))

            batchcmds:mkdir(path.directory(objfile))
            local comp_tag = is_cxx and "compiling.evc3.c++" or "compiling.evc3"
            batchcmds:show_progress(opt.progress, "${color.build.object}%s (%s) %s", comp_tag, arch, path.relative(sourcefile, os.projectdir()))
            if wibo then
                batchcmds:vrunv(wibo, argv, {envs = envs, curdir = os.projectdir()})
            else
                table.remove(argv, 1)
                batchcmds:vrunv(cl_exe, argv, {envs = envs, curdir = os.projectdir()})
            end

            -- Header dependency tracking via recursive include scanning
            local searchdirs = table.join({path.directory(sourcefile)}, incdirs, {path.join(s, "include")})
            local depfiles = {sourcefile}
            local headers = scan_evc3_includes(sourcefile, searchdirs)
            for _, h in ipairs(headers) do
                table.insert(depfiles, h)
            end

            batchcmds:add_depfiles(table.unpack(depfiles))
            batchcmds:set_depmtime(os.mtime(objfile))
            batchcmds:set_depcache(target:dependfile(objfile))
        end)

        on_linkcmd(function (target, batchcmds, opt)
            local s = target:data("evc3.sdk")
            local wibo = target:data("evc3.wibo")
            local arch = target:data("evc3.arch") or get_config("arch") or "arm"
            local targetfile = target:targetfile()

            batchcmds:mkdir(path.directory(targetfile))

            local envs = {
                INCLUDE = path.join(s, "include"),
                LIB = path.join(s, "lib", arch)
            }

            local machine_map = {
                arm = "ARM",
                mips = "MIPS",
                ppc = "PPC",
                sh3 = "SH3",
                sh4 = "SH4",
                x86 = "IX86"
            }
            local machine = machine_map[arch] or "ARM"

            local objs = import("modules.objectfiles", {rootdir = path.join(os.scriptdir(), "../../..")}).collect(target)

            if target:is_binary() or target:is_shared() then
                local link_exe = path.join(s, "bin", "link.exe")
                local argv = {
                    link_exe,
                    "/nologo",
                    "/nodefaultlib",
                    "/subsystem:windowsce,3.00",
                    "/MACHINE:" .. machine,
                    "/libpath:" .. to_wibo_path(path.join(s, "lib", arch)),
                    "/out:" .. to_wibo_path(path.absolute(targetfile))
                }

                if target:is_shared() then
                    table.insert(argv, "/dll")
                end

                local ldflags = table.wrap(target:get("ldflags"))
                local has_entry = false
                for _, f in ipairs(ldflags) do
                    if f:lower():find("^/entry:") or f:lower():find("^-entry:") then
                        has_entry = true
                    end
                    table.insert(argv, f)
                end

                local custom_entry = target:values("recudo.toolchain.evc3.entry")
                if custom_entry and not has_entry then
                    table.insert(argv, "/entry:" .. custom_entry)
                    has_entry = true
                end

                if not has_entry and target:is_binary() then
                    -- Standard Windows CE GUI apps enter via WinMainCRTStartup (which invokes WinMain).
                    -- Console/CLI applications with a standard main() should specify /entry:mainACRTStartup
                    -- via set_values("recudo.toolchain.evc3.entry", "mainACRTStartup") or add_ldflags("/entry:mainACRTStartup").
                    table.insert(argv, "/entry:WinMainCRTStartup")
                end

                for _, obj in ipairs(objs) do
                    table.insert(argv, to_wibo_path(path.absolute(obj)))
                end

                for _, linkdir in ipairs(collect_target_values(target, "linkdirs")) do
                    table.insert(argv, "/libpath:" .. to_wibo_path(path.absolute(linkdir)))
                end

                local linked_files = {}
                for _, libfile in ipairs(collect_target_values(target, "libfiles")) do
                    table.insert(argv, to_wibo_path(path.absolute(libfile)))
                    local b = path.basename(libfile):lower()
                    linked_files[b] = true
                    if b:startswith("lib") then
                        linked_files[b:sub(4)] = true
                    end
                end

                for _, link in ipairs(collect_target_values(target, "links")) do
                    local l = link:lower()
                    if not linked_files[l] then
                        local libname = (link:endswith(".lib") or link:endswith(".a")) and link or (link .. ".lib")
                        table.insert(argv, libname)
                    end
                end

                table.insert(argv, "coredll.lib")
                table.insert(argv, "corelibc.lib")
                table.insert(argv, "winsock.lib")

                local tag = target:is_shared() and "linking.evc3.dll" or "linking.evc3"
                batchcmds:show_progress(opt.progress, "${color.build.target}%s (%s) %s", tag, arch, targetfile)
                if wibo then
                    batchcmds:vrunv(wibo, argv, {envs = envs, curdir = os.projectdir()})
                else
                    table.remove(argv, 1)
                    batchcmds:vrunv(link_exe, argv, {envs = envs, curdir = os.projectdir()})
                end
            else
                local lib_exe = path.join(s, "bin", "lib.exe")
                local argv = {
                    lib_exe,
                    "/nologo",
                    "/out:" .. to_wibo_path(path.absolute(targetfile))
                }
                for _, obj in ipairs(objs) do
                    table.insert(argv, to_wibo_path(path.absolute(obj)))
                end

                batchcmds:show_progress(opt.progress, "${color.build.target}archiving.evc3 (%s) %s", arch, targetfile)
                if wibo then
                    batchcmds:vrunv(wibo, argv, {envs = envs, curdir = os.projectdir()})
                else
                    table.remove(argv, 1)
                    batchcmds:vrunv(lib_exe, argv, {envs = envs, curdir = os.projectdir()})
                end
            end
        end)
end

setup_evc3_rule("recudo.toolchain.evc3")
setup_evc3_rule("recudo.evc3")
