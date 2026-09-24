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
