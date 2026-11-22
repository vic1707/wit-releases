-- Release builds of Wiimm's ISO Tools (https://github.com/Wiimm/wiimms-iso-tools).
--
--   xmake f -y [--wit_version=3.05a]   # pick an upstream version (default: newest)
--   xmake -y                           # fetch + build upstream at the pinned commit,
--                                      # then pack build/dist/wit-v<ver>-<os>-<arch>.tar.gz

set_project("wit-releases")
set_xmakever("3.1.2")

-- Upstream versions, newest first: { version, upstream commit sha }.
-- Adding a line here + pushing tag v<version> publishes a release.
local VERSIONS = {
    {"3.05a", "fc1c0b840cb3ac41ca6e4f1d5e16da12b47eab58"},
}

package("wiimms-iso-tools")
    set_kind("binary")
    set_homepage("https://wit.wiimm.de/")
    set_description("Wiimms ISO Tools: wit, wwt, wdf")
    set_license("GPL-2.0")
    set_urls("https://github.com/Wiimm/wiimms-iso-tools.git")
    for _, v in ipairs(VERSIONS) do
        add_versions(v[1], v[2])
    end
    add_deps("zlib")

    on_install("linux", "macosx", function (package)
        -- upstream's GNU make build is replaced by our xmake port (./port)
        os.cp(path.join(package:scriptdir(), "port", "*.lua"), "project/")
        os.cd("project")
        import("package.tools.xmake").install(package)
    end)

    on_test(function (package)
        os.vrunv(path.join(package:installdir("bin"), "wit"), {"version"})
    end)
package_end()

option("wit_version")
    set_default(VERSIONS[1][1])
    set_showmenu(true)
    set_description("Upstream wiimms-iso-tools version to build (see VERSIONS in xmake.lua)")
option_end()

add_requires("wiimms-iso-tools " .. (get_config("wit_version") or VERSIONS[1][1]))

-- Packs the installed package into a mise-friendly archive:
--   wit-v<ver>-<os>-<arch>.tar.gz  containing  bin/ share/wit/ gpl-2.0.txt
target("dist")
    set_kind("phony")
    add_packages("wiimms-iso-tools")
    on_build(function (target)
        local pkg = target:pkg("wiimms-iso-tools")
        local os_name = ({macosx = "macos"})[target:plat()] or target:plat()
        local arch = target:arch()
        if os_name == "linux" and arch == "arm64" then
            arch = "aarch64"
        end
        local version = get_config("wit_version") or VERSIONS[1][1]
        local name = ("wit-v%s-%s-%s"):format(version, os_name, arch)
        local outdir = path.absolute(path.join(get_config("builddir") or "build", "dist"))
        local archive = path.join(outdir, name .. ".tar.gz")
        os.mkdir(outdir)
        os.tryrm(archive)
        os.vrunv("tar", {"-czf", archive, "-C", pkg:installdir(), "bin", "share", "gpl-2.0.txt"},
                 {envs = {COPYFILE_DISABLE = "1"}}) -- no macOS ._* resource forks
        cprint("${bright green}packed${clear} %s", archive)
    end)
target_end()
