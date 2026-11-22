-- Code generation for the wit port, replacing upstream's templates.sed +
-- gen-template.sh (version.h) and gen-text-file.sh (text-files/*.inc).
-- Loaded from xmake.lua with import("codegen") in on_config, so it runs in
-- xmake's script scope (full io/os access).

import("core.project.config")

-- Read `NAME = value` assignments from upstream's Makefile (first occurrence wins,
-- which picks the BETA_VERSION=0 branch of the URI_* conditionals).
local function makefile_vars(file)
    local vars = {}
    for line in io.lines(file) do
        local k, v = line:match("^%s*([A-Z][A-Z0-9_]*)%s*:?=%s*(.-)%s*$")
        if k and vars[k] == nil then
            vars[k] = v
        end
    end
    return vars
end

-- Timestamp for BINTIME/DATE/TIME: SOURCE_DATE_EPOCH > upstream commit time > now.
local function build_epoch()
    local epoch = tonumber(os.getenv("SOURCE_DATE_EPOCH") or "")
    if not epoch then
        local out = try { function () return os.iorunv("git", {"log", "-1", "--format=%ct"}) end }
        epoch = out and tonumber(out:trim()) or nil
    end
    return epoch or os.time()
end

-- Port of gen-text-file.sh: turn text-files/<name>.inc into a C string array.
local function gen_text_file(srcdir, name, outdir)
    local base = name:gsub("%.[^.]*$", "")
    local varname = "text_" .. base:gsub("[-.]", "_")
    local guard = ("SZS_" .. varname .. "_INC"):upper()
    local eol = varname:match("_cr$") and "\\r\\n" or "\\n"
    local out = {("\n#ifndef %s\n#define %s 1\n"):format(guard, guard)}
    table.insert(out, ("\nconst char %s[] =\n{\n"):format(varname))
    for line in io.lines(path.join(srcdir, name)) do
        if not line:startswith("~") then
            line = line:gsub("\\", "\\\\"):gsub("\"", "\\\"")
            line = line:gsub("#FF#", "#\\f", 1)
            table.insert(out, "  \"" .. line .. eol .. "\"\n")
        end
    end
    table.insert(out, "};\n\n")
    table.insert(out, ("#endif // %s\n\n"):format(guard))
    return table.concat(out)
end

local function write_if_changed(file, content)
    if not os.isfile(file) or io.readfile(file) ~= content then
        io.writefile(file, content)
    end
end

-- Generate version.h + text includes into <builddir>/gen.
function main(target)
    local projdir = os.projectdir()
    local gendir = path.join(path.absolute(config.builddir(), projdir), "gen")
    os.mkdir(gendir)

    local mk = makefile_vars(path.join(projdir, "Makefile"))
    local beta = tonumber(mk.BETA_VERSION or "0") or 0
    local beta_suffix = beta == 0 and "" or (beta == -1 and ".beta" or (".beta" .. beta))

    local revision = "0"
    local revfile = path.join(projdir, "revision.sh")
    if os.isfile(revfile) then
        revision = io.readfile(revfile):match("revision=(%S+)") or "0"
    end
    local rev_num = tonumber((revision:gsub("[^0-9]", ""))) or 0
    local rev_next = tostring(revision) == tostring(rev_num) and rev_num or rev_num + 1

    local epoch = build_epoch()
    local install_path = "/usr/local"
    local subst = {
        ["@.@@@"] = mk.VERSION_NUM,
        ["@@@@-@@-@@"] = os.date("!%Y-%m-%d", epoch),
        ["@@:@@:@@"] = os.date("!%H:%M:%S", epoch),
        ["@@AUTHOR@@"] = mk.AUTHOR,
        ["@@TOOLSET-SHORT@@"] = mk.TOOLSET_SHORT,
        ["@@TOOLSET-LONG@@"] = mk.TOOLSET_LONG,
        ["@@WIT-SHORT@@"] = mk.WIT_SHORT,
        ["@@WIT-LONG@@"] = mk.WIT_LONG,
        ["@@WWT-SHORT@@"] = mk.WWT_SHORT,
        ["@@WWT-LONG@@"] = mk.WWT_LONG,
        ["@@WDF-SHORT@@"] = mk.WDF_SHORT,
        ["@@WDF-LONG@@"] = mk.WDF_LONG,
        ["@@WFUSE-SHORT@@"] = mk.WFUSE_SHORT,
        ["@@WFUSE-LONG@@"] = mk.WFUSE_LONG,
        ["@@VERSION@@"] = mk.VERSION_NUM .. beta_suffix,
        ["@@VERSION-NUM@@"] = mk.VERSION_NUM,
        ["@@BETA-VERSION@@"] = tostring(beta),
        ["@@BETA-SUFFIX@@"] = beta_suffix,
        ["@@REV@@"] = revision,
        ["@@REV-NUM@@"] = tostring(rev_num),
        ["@@REV-NEXT@@"] = tostring(rev_next),
        ["@@BINTIME@@"] = tostring(epoch),
        ["@@DATE@@"] = os.date("!%Y-%m-%d", epoch),
        ["@@TIME@@"] = os.date("!%H:%M:%S", epoch),
        ["@@INSTALL-PATH@@"] = install_path,
        ["@@SHARE-PATH@@"] = install_path .. "/share/wit",
        ["@@WIN-INSTALL-PATH@@"] = "Wiimm/WIT",
        ["@@URI-REPOS@@"] = mk.URI_REPOS,
        ["@@URI-VIEWVC@@"] = mk.URI_VIEWVC,
        ["@@URI-HOME@@"] = mk.URI_HOME,
        ["@@URI-DOWNLOAD@@"] = mk.URI_DOWNLOAD,
    }

    local lines = {}
    for line in io.lines(path.join(projdir, "setup", "version.h")) do
        if not line:startswith("~") then
            line = line:gsub("@[@.:%-A-Z0-9]*@", function (key)
                return subst[key]
            end)
            table.insert(lines, line)
        end
    end
    local version_h = table.concat(lines, "\n") .. "\n"
    local unresolved = version_h:match("@@[A-Z0-9%-]+@@")
    assert(not unresolved, "version.h: unknown placeholder " .. tostring(unresolved))
    write_if_changed(path.join(gendir, "version.h"), version_h)

    local textdir = path.join(projdir, "text-files")
    for _, name in ipairs({"logo.inc", "ui-head.inc", "config-paths.inc"}) do
        write_if_changed(path.join(gendir, name), gen_text_file(textdir, name, gendir))
    end

    target:add("includedirs", gendir, {public = true})
end

