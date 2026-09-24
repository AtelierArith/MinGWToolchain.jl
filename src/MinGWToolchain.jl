module MinGWToolchain

using Artifacts
using LazyArtifacts

const _ARTIFACT_NAME = "mingw_toolchain"

export toolchain_root, bindir, tool, is_available
export gcc, gxx, gfortran
export ar, as, ld, nm, objcopy, objdump, ranlib, strip, windres
export toolchain_version, with_toolchain

"""
    UnsupportedPlatformError(kernel, arch)

Raised when `MinGWToolchain` is used on a platform without a supported artifact.
"""
struct UnsupportedPlatformError <: Exception
    kernel::Symbol
    arch::Symbol
end

"""
    ToolNotFoundError(tool, bindir)

Raised when a requested executable does not exist in the toolchain `bindir`.
"""
struct ToolNotFoundError <: Exception
    tool::String
    bindir::String
end

"""
    InvalidArtifactLayoutError(artifact_root)

Raised when the downloaded artifact does not contain a recognizable MinGW layout.
"""
struct InvalidArtifactLayoutError <: Exception
    artifact_root::String
end

function Base.showerror(io::IO, e::UnsupportedPlatformError)
    print(
        io,
        "MinGWToolchain is not supported on ",
        e.kernel,
        "/",
        e.arch,
        ". Only Windows/x86_64 is supported.",
    )
end

function Base.showerror(io::IO, e::ToolNotFoundError)
    print(io, "tool '", e.tool, "' was not found in ", e.bindir)
end

function Base.showerror(io::IO, e::InvalidArtifactLayoutError)
    print(
        io,
        "could not detect a MinGW toolchain layout under ",
        e.artifact_root,
        ". Expected to find bin/gcc.exe.",
    )
end

_artifact_path(name::AbstractString) = @artifact_str(name)

function _artifact_root()
    Sys.iswindows() || throw(UnsupportedPlatformError(Sys.KERNEL, Sys.ARCH))
    Sys.ARCH == :x86_64 || throw(UnsupportedPlatformError(Sys.KERNEL, Sys.ARCH))
    return _artifact_path(_ARTIFACT_NAME)
end

function _detect_toolchain_root(root::AbstractString)
    candidates = (
        joinpath(root, "extracted_files", "mingw64"),
        joinpath(root, "mingw64"),
        root,
    )
    for candidate in candidates
        isfile(joinpath(candidate, "bin", "gcc.exe")) && return candidate
    end
    throw(InvalidArtifactLayoutError(String(root)))
end

"""
    toolchain_root() -> String

Return the absolute path to the root of the MinGW toolchain.

The artifact is downloaded lazily on first use.
"""
toolchain_root() = _detect_toolchain_root(_artifact_root())

"""
    bindir() -> String

Return the absolute path to the toolchain `bin` directory.
"""
bindir() = joinpath(toolchain_root(), "bin")

"""
    tool(name) -> String

Return the absolute path to the executable `name` inside the toolchain.

The `.exe` suffix is optional on Windows. A [`ToolNotFoundError`](@ref) is raised
if the executable does not exist.
"""
function tool(name::AbstractString)
    exe = endswith(lowercase(name), ".exe") ? String(name) : String(name) * ".exe"
    path = joinpath(bindir(), exe)
    isfile(path) || throw(ToolNotFoundError(String(name), bindir()))
    return path
end

"""
    is_available(name) -> Bool

Return `true` if the executable `name` exists in the toolchain.
"""
is_available(name::AbstractString) = try
    tool(name)
    true
catch e
    e isa ToolNotFoundError || rethrow()
    false
end

"""
    gcc() -> String

Return the absolute path to `gcc.exe`.
"""
gcc() = tool("gcc")

"""
    gxx() -> String

Return the absolute path to `g++.exe`.
"""
gxx() = tool("g++")

"""
    gfortran() -> String

Return the absolute path to `gfortran.exe`.
"""
gfortran() = tool("gfortran")

"""
    ar() -> String

Return the absolute path to `ar.exe`.
"""
ar() = tool("ar")

"""
    as() -> String

Return the absolute path to `as.exe`.
"""
as() = tool("as")

"""
    ld() -> String

Return the absolute path to `ld.exe`.
"""
ld() = tool("ld")

"""
    nm() -> String

Return the absolute path to `nm.exe`.
"""
nm() = tool("nm")

"""
    objcopy() -> String

Return the absolute path to `objcopy.exe`.
"""
objcopy() = tool("objcopy")

"""
    objdump() -> String

Return the absolute path to `objdump.exe`.
"""
objdump() = tool("objdump")

"""
    ranlib() -> String

Return the absolute path to `ranlib.exe`.
"""
ranlib() = tool("ranlib")

"""
    strip() -> String

Return the absolute path to `strip.exe`.
"""
strip() = tool("strip")

"""
    windres() -> String

Return the absolute path to `windres.exe`.
"""
windres() = tool("windres")

"""
    toolchain_version() -> VersionNumber

Return the GCC version reported by the toolchain, e.g. `v"14.2.0"`.
"""
function toolchain_version()
    s = Base.strip(read(`$(gcc()) -dumpfullversion`, String))
    isempty(s) && (s = Base.strip(read(`$(gcc()) -dumpversion`, String)))
    return VersionNumber(s)
end

"""
    with_toolchain(f; set_compiler_vars=true)

Run `f` with the toolchain `bin` directory prepended to `PATH`.

When `set_compiler_vars` is `true`, the `CC`, `CXX`, `FC`, `AR`, `RANLIB` and
`RC` environment variables are also set to the corresponding toolchain
executables. The environment is restored when `f` returns, even on error.

```julia
with_toolchain() do
    run(`gcc --version`)
    run(`gfortran hello.f90 -o hello.exe`)
end
```
"""
function with_toolchain(f::Function; set_compiler_vars::Bool=true)
    b = bindir()
    oldpath = get(ENV, "PATH", "")
    newpath = isempty(oldpath) ? b : string(b, ';', oldpath)

    pairs = Pair{String,String}["PATH" => newpath]
    if set_compiler_vars
        append!(pairs, [
            "CC" => gcc(),
            "CXX" => gxx(),
            "FC" => gfortran(),
            "AR" => ar(),
            "RANLIB" => ranlib(),
            "RC" => windres(),
        ])
    end

    return Base.withenv(f, pairs...)
end

end # module MinGWToolchain
