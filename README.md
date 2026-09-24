# MinGWToolchain.jl

`MinGWToolchain.jl` provides a MinGW-w64 based GCC toolchain (`gcc`, `g++`,
`gfortran` and GNU binutils) for Julia on Windows x86_64, without requiring a
manual MSYS2 / MinGW-w64 installation.

The toolchain binary is **not** bundled with this package. It is downloaded
lazily from a pinned, content-addressed Julia artifact (see `Artifacts.toml`).

Supported platform:

| OS | Architecture |
|---|---|
| Windows | x86_64 |

All other platforms raise `MinGWToolchain.UnsupportedPlatformError`.

## Relationship to WinGet and MSYS2

If you only need a system-wide GCC/GFortran installation on Windows, WinGet /
WinLibs may be simpler:

```powershell
winget install --id BrechtSanders.WinLibs.POSIX.UCRT -e
```

The UCRT variant is the default choice; for MSVCRT use
`BrechtSanders.WinLibs.POSIX.MSVCRT` instead. Both install `gcc`, `g++` and
`gfortran` and expose them on the system `PATH`.

`MinGWToolchain.jl` is not a replacement for WinGet or MSYS2. Its purpose is to
treat the Windows native compiler toolchain as a **reproducible dependency of a
Julia package**:

- works without WinGet
- no system-wide installation and no permanent `PATH` changes
- compiler version pinned by artifact metadata and hashes
- the same toolchain across CI and user environments
- compiler paths discoverable programmatically

| Approach | Primary use |
|---|---|
| WinGet + WinLibs | set up a human developer environment on Windows |
| MinGWToolchain.jl + Artifacts | a Julia package acquires and uses a compiler reproducibly |
| MSYS2 | a Unix-like shell plus a broad set of development packages |

`MinGWToolchain.jl` exists not to install MinGW on Windows, but to make a
Windows native compiler toolchain usable as a reproducible dependency inside the
Julia package ecosystem.

## Install

```julia
using Pkg
Pkg.add(url = "https://github.com/atelierarith/MinGWToolchain.jl")
```

## Quickstart

```julia
using MinGWToolchain

run(`$(gcc()) --version`)
run(`$(gfortran()) --version`)
```

Compile and run Fortran:

```julia
write("hello.f90", """
program hello
    print *, "Hello from Fortran!"
end program hello
""")

with_toolchain() do
    run(`$(gfortran()) hello.f90 -O2 -o hello.exe`)
    run(`./hello.exe`)
end
```

`with_toolchain()` prepends the toolchain `bin` directory to `PATH` and sets the
usual compiler variables (`CC`, `CXX`, `FC`, `AR`, `RANLIB`, `RC`) for the
duration of the block. This makes the toolchain runtime DLLs (e.g.
`libgfortran-5.dll`, `libstdc++-6.dll`) discoverable. The environment is always
restored, even if an exception is thrown.

## Windows application-control environments

On Windows 11, including Windows 11 Pro, Smart App Control or an App Control
for Business / Code Integrity policy can block unsigned DLLs. Julia normally
creates unsigned DLLs for package precompilation under
`%USERPROFILE%\.julia\compiled`. Such a policy can therefore reject the
precompiled `MinGWToolchain` cache even when the package and Julia installation
are otherwise valid.

To avoid requiring a user-side security-policy change, this package disables
precompilation on Windows and loads its small module from source instead. This
may slightly increase import time on Windows. The core compiler and
shared-library tests run without external build-system dependencies.

See Microsoft's documentation for [Smart App Control](https://learn.microsoft.com/en-us/windows/apps/develop/smart-app-control/overview)
and [App Control for Business feature availability](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/feature-availability).

## API

- `toolchain_root()`, `bindir()`
- `tool(name)`, `is_available(name)`
- `gcc()`, `gxx()`, `gfortran()`
- `ar()`, `as()`, `ld()`, `nm()`, `objcopy()`, `objdump()`, `ranlib()`,
  `strip()`, `windres()`
- `toolchain_version()`
- `with_toolchain(f; set_compiler_vars=true)`

Every path-returning function validates that the executable exists.

## License

The Julia source code in this repository is MIT licensed. The downloaded
MinGW-w64/GCC toolchain is third-party software distributed under its own
upstream licenses; see `THIRD_PARTY_NOTICES.md`.
