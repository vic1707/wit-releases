-- xmake port of Wiimm's ISO Tools (https://github.com/Wiimm/wiimms-iso-tools).
--
-- This file is copied into the upstream `project/` directory by the
-- `wiimms-iso-tools` package (see ../xmake.lua) and replaces upstream's
-- GNU make build. It reproduces what `make all` / `STATIC=1 make distrib` do:
--   * generate version.h from setup/version.h (upstream: templates.sed + gen-template.sh)
--   * generate logo.inc, ui-head.inc, config-paths.inc (upstream: gen-text-file.sh)
--     -> both live in codegen.lua
--   * build wit, wwt, wdf (wfuse is skipped: needs libfuse/macFUSE)
-- The gen-ui output (src/ui/ui-*.c|h, ui.def) is committed upstream and used as is.

set_project("wiimms-iso-tools")
set_xmakever("3.1.2")
set_languages("gnu99")
add_rules("mode.release")

add_requires("zlib", {system = false, configs = {shared = false}})

-- Settings shared by every target (upstream Makefile: DEFINES1 / CFLAGS).
local function common()
    add_includedirs("dclib", "src/libwbfs", "src", "src/ui", ".")
    add_defines(
        "LARGE_FILES", "_FILE_OFFSET_BITS=64",
        "WIT",                  -- compile wit tools (shared sources, e.g. libwbfs)
        "DEBUG_ASSERT",         -- upstream keeps ASSERTs in release builds
        "EXTENDED_ERRORS=1",
        "_7ZIP_ST=1", "_LZMA_PROB32=1",
        "HAVE_ZLIB=1")
    add_cflags("-fomit-frame-pointer", "-fno-strict-aliasing", "-funroll-loops", "-O3")
    add_cflags("-Wall", "-Wno-parentheses", "-Wno-unused-function")
    add_cflags("-Wno-format-truncation", {tools = "gcc"})
    if is_plat("macosx") then
        add_cflags("-Wno-gnu-variable-sized-type-not-at-end", "-Wno-address-of-packed-member")
    end
    if is_plat("linux") then
        add_defines("HAVE_POSIX_FALLOCATE=1", "HAVE_FIEMAP=1")
    end
end

target("witcore")
    set_kind("static")
    common()
    add_packages("zlib", {public = true})
    on_install(function () end) -- internal helper lib, not shipped
    on_config(function (target)
        import("codegen", {rootdir = os.scriptdir()})(target)
    end)

    -- dclib (dclib/Makefile.inc: DCLIB_O, plus lib-dol from WIT_O)
    for _, f in ipairs({"basics", "cli", "color", "numeric", "parser", "file", "option",
                        "regex", "utf8", "shift-jis", "vector", "tables", "ui", "xdump",
                        "debug"}) do
        add_files("dclib/dclib-" .. f .. ".c")
    end
    add_files("dclib/lib-dol.c")

    -- WIT_O
    add_files(
        "src/lib-std.c", "src/lib-file.c", "src/lib-sf.c",
        "src/lib-bzip2.c", "src/lib-lzma.c",
        "src/lib-wdf.c", "src/lib-wia.c", "src/lib-ciso.c", "src/lib-gcz.c",
        "src/iso-interface.c", "src/wbfs-interface.c", "src/patch.c",
        "src/titles.c", "src/match-pattern.c",
        "src/crypto/sha1dgst.c", "src/crypto/sha1_one.c")

    -- LIBWBFS_O
    add_files(
        "src/libwbfs/tools.c", "src/libwbfs/file-formats.c", "src/libwbfs/libwbfs.c",
        "src/libwbfs/wiidisc.c", "src/libwbfs/cert.c", "src/libwbfs/rijndael.c")

    -- bundled libbz2 + lzma
    add_files("src/libbz2/*.c", "src/lzma/*.c")
    if not is_plat("macosx") then
        add_cflags("-Wno-unused-but-set-variable", "-Wno-maybe-uninitialized", {tools = "gcc"})
    end

    -- SHA1 assembly (self-selects x86 code on linux/cygwin, empty elsewhere)
    add_includedirs("src/crypto")
    add_files("src/crypto/ssl-asm.S")
target_end()

for _, tool in ipairs({"wit", "wwt", "wdf"}) do
    target(tool)
        set_kind("binary")
        common()
        add_deps("witcore")
        add_files("src/" .. tool .. ".c")
        if tool == "wit" then
            add_files("src/wit-mix.c")
        end
        if is_plat("linux") then
            add_syslinks("ncurses", "tinfo", "m")
            add_ldflags("-static", "-static-libgcc", {force = true})
        else
            add_syslinks("ncurses", "m")
        end
        if tool == "wdf" then
            after_install(function (target)
                -- upstream WDF_LINKS: wdf-cat, wdf-dump are hard links to wdf
                local bindir = path.join(target:installdir(), "bin")
                for _, link in ipairs({"wdf-cat", "wdf-dump"}) do
                    os.cp(path.join(bindir, target:filename()),
                          path.join(bindir, link .. path.extension(target:filename())))
                end
            end)
        end
        if tool == "wit" then
            after_install(function (target)
                local root = target:installdir()
                os.cp(path.join(os.projectdir(), "share", "*.txt"), path.join(root, "share", "wit") .. "/")
                os.cp(path.join(os.projectdir(), "gpl-2.0.txt"), root .. "/")
            end)
        end
    target_end()
end
