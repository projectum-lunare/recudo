-- Object files for a target when a custom rule drives the link.
-- Watcom and eVC3 both link outside the stock linker, so they share this list.

function collect(target)
    local objs = {}
    local raw_objs = target:objectfiles()
    if raw_objs and #raw_objs > 0 then
        for _, obj in ipairs(raw_objs) do
            table.insert(objs, obj)
        end
    else
        for _, src in ipairs(table.wrap(target:sourcefiles())) do
            if src:endswith(".c") or src:endswith(".cpp") or src:endswith(".cc") or src:endswith(".cxx") then
                table.insert(objs, target:objectfile(src))
            end
        end
    end
    return table.unique(objs)
end
