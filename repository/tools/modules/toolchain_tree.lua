-- Projectum Lunare Recudo - shared provisioning helpers
--
-- The toolchain package recipes (repository/tools/packages/*/*/xmake.lua)
-- all need the same tree plumbing, and xmake's own file API is not enough for
-- archives: os.cp("*") does not recurse into directories nor create the
-- destination parent, and path.basename truncates version-like names
-- ("13.3.0" becomes "13"). These helpers encode the working sequence once.
--
-- Import from a recipe:
--   local tree = import("toolchain_tree",
--       {rootdir = path.join(os.scriptdir(), "../../../modules")})

-- Recursive copy that keeps symlinks and preserves directory names verbatim.
-- path.filename is used for directories on purpose: path.basename would strip
-- a "13.3.0" segment down to "13".
function copy_tree(src, dst)
    os.mkdir(dst)
    for _, f in ipairs(os.files(path.join(src, "*")) or {}) do
        local target = path.join(dst, path.filename(f))
        -- a dangling symlink (the eVC ISOs carry lowercased links to names
        -- that only exist in uppercase) makes os.cp fail: recreate it instead
        local ok = try {
            function ()
                os.cp(f, target, {symlink = true})
                return true
            end
        }
        if not ok then
            local link = io.readlink and io.readlink(f)
            if link then
                os.ln(link, target)
            end
        end
    end
    for _, d in ipairs(os.dirs(path.join(src, "*")) or {}) do
        copy_tree(d, path.join(dst, path.filename(d)))
    end
end

-- Archives usually wrap their payload in one top directory. Returns that
-- directory when the root holds exactly one directory and no files, else the
-- root itself.
function descend(root)
    if os.isdir(path.join(root, "bin")) then
        return root
    end
    local tops = os.dirs(path.join(root, "*")) or {}
    local files = os.files(path.join(root, "*")) or {}
    if #tops == 1 and #files == 0 then
        return tops[1]
    end
    return root
end

-- Copy every entry of src (directories recursively) into dst.
function merge_into(src, dst)
    for _, entry in ipairs(table.join(os.dirs(path.join(src, "*")) or {},
                                      os.files(path.join(src, "*")) or {})) do
        local target = path.join(dst, path.filename(entry))
        if os.isdir(entry) then
            copy_tree(entry, target)
        else
            os.cp(entry, target, {symlink = true})
        end
    end
end

-- Unpack a .deb (an ar archive wrapping data.tar.{zst,gz,xz}) and return the
-- directory holding the package payload.
function unpack_deb(deb, workdir)
    os.tryrm(workdir)
    os.mkdir(workdir)
    os.runv("ar", {"x", deb}, {curdir = workdir, force = true})

    local data = nil
    for _, f in ipairs(os.files(path.join(workdir, "data.tar.*")) or {}) do
        data = f
    end
    assert(data, "data.tar not found inside " .. deb)

    local out = path.join(workdir, "data")
    os.mkdir(out)
    local extracted = try {
        function ()
            import("utils.archive").extract(data, out)
        end
    }
    if not extracted then
        os.runv("tar", {"-xf", data, "-C", out})
    end
    return out
end

-- Merge a .deb's usr/ level into the toolchain tree.
function install_deb(deb, installdir, workdir)
    local payload = unpack_deb(deb, workdir)
    local usr = path.join(payload, "usr")
    merge_into(os.isdir(usr) and usr or payload, installdir)
end

-- sha256 of a file through whichever tool the host provides. Returns nil when
-- none is available (callers then fail with their own message).
function sha256_of(file)
    for _, tool in ipairs({{"sha256sum"}, {"shasum", "-a", "256"}, {"openssl", "sha256"}}) do
        local hex = nil
        try {
            function ()
                hex = tostring(os.iorunv(tool[1], table.join(tool[2] or {}, {file})))
                    :match("^%s*([a-fA-F0-9]+)")
            end
        }
        if hex and #hex >= 64 then
            return hex:sub(1, 64):lower()
        end
    end
    return nil
end

-- Download url to dest (unless already there) and verify its sha256.
function fetch_pinned(url, sha, dest)
    if not os.isfile(dest) then
        local http = import("net.http")
        http.download(url, dest)
    end
    local got = sha256_of(dest)
    if not got or got ~= sha:lower() then
        raise("checksum mismatch for %s: expected %s, got %s", dest, sha, tostring(got))
    end
    return dest
end

-- Mirror an installed tree into the canonical contract location used by the
-- detection layer: ~/.local/opt/<name> on Unix, %APPDATA%/<name> on Windows.
function mirror_to(installdir, name)
    local target = nil
    if os.host() == "windows" then
        local appdata = os.getenv("APPDATA") or os.getenv("LOCALAPPDATA")
        target = appdata and path.join(appdata, name)
    else
        local home = os.getenv("HOME")
        target = home and path.join(home, ".local/opt", name)
    end
    if target and not os.isdir(target) then
        copy_tree(installdir, target)
    end
    return target
end

-- chmod +x every file in a directory (POSIX hosts only).
function make_executable(dir)
    if os.host() == "windows" then
        return
    end
    for _, f in ipairs(os.files(path.join(dir, "*")) or {}) do
        -- skip dangling symlinks: chmod refuses them, and their target may be
        -- a name that only exists in the other case (the eVC ISO trees)
        try {
            function ()
                os.runv("chmod", {"0755", f})
            end
        }
    end
end

-- Run a compiler command and return the combined stdout+stderr (many of these
-- tools print their banner to stderr).
function run_capture(program, args, envs, curdir)
    local out, err = nil, nil
    try {
        function ()
            out, err = os.iorunv(program, args or {}, {envs = envs, curdir = curdir})
        end,
        catch {
            function (e)
                err = tostring(e)
            end
        }
    }
    return tostring(out or "") .. tostring(err or "")
end
