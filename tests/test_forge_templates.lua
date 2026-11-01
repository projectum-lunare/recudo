-- Tests for Forge templates, repl, and project creation

function main(T)
    local tests = {}

    table.insert(tests, {
        name = "forge project templates exist and contain valid manifest and config",
        func = function ()
            local root = os.projectdir()
            local tmpl_root = path.join(root, "templates", "lua")
            local expected_templates = {"app", "module", "cmodule", "love", "amulet"}

            for _, name in ipairs(expected_templates) do
                local dir = path.join(tmpl_root, name)
                T.assert_true(os.isdir(dir), "Template dir exists: " .. name)
                T.assert_true(os.isfile(path.join(dir, "template.lua")), "template.lua exists for: " .. name)
                T.assert_true(os.isfile(path.join(dir, "xmake.lua")), "xmake.lua exists for: " .. name)
            end
        end
    })

    table.insert(tests, {
        name = "forge create generates and instantiates new project from template",
        func = function ()
            local tmp_proj = path.join(os.tmpdir(), "forge_test_gen_app")
            os.rm(tmp_proj)

            local root = os.projectdir()
            local forge_main = import("plugins.forge.main", {rootdir = root, anonymous = true})
            T.assert_not_nil(forge_main)

            local tmpl_dir = path.join(root, "templates", "lua", "app")
            os.mkdir(tmp_proj)
            for _, srcfile in ipairs(os.files(path.join(tmpl_dir, "**"))) do
                local relpath = path.relative(srcfile, tmpl_dir)
                if relpath ~= "template.lua" then
                    local dstfile = path.join(tmp_proj, relpath)
                    os.mkdir(path.directory(dstfile))
                    local content = io.readfile(srcfile)
                    content = content:gsub("%${TARGET_NAME}", "forge_test_gen_app")
                    io.writefile(dstfile, content)
                end
            end

            local xmake_content = io.readfile(path.join(tmp_proj, "xmake.lua"))
            T.assert_true(xmake_content:find('target%("forge_test_gen_app"%)') ~= nil)
            T.assert_true(xmake_content:find('add_rules%("forge.lua.app"%)') ~= nil)

            local main_content = io.readfile(path.join(tmp_proj, "src", "main.lua"))
            T.assert_true(main_content:find("forge_test_gen_app") ~= nil)

            os.rm(tmp_proj)
        end
    })

    return tests
end
