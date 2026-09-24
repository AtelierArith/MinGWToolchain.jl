# Third-party notices

`MinGWToolchain.jl` itself is licensed under the MIT License (see `LICENSE`).

The MinGW-w64/GCC toolchain downloaded through `Artifacts.toml` is third-party
software and is **not** covered by the MIT License of this Julia package.

Initial artifact provenance:

- Repacked binary distribution:
  https://github.com/JuliaLang/PackageCompiler.jl/releases/tag/v2.1.24
- Upstream MinGW-w64 GCC builds:
  https://github.com/niXman/mingw-builds-binaries
- MinGW-w64:
  https://github.com/mingw-w64/mingw-w64
- GCC:
  https://gcc.gnu.org/
- GNU binutils:
  https://www.gnu.org/software/binutils/

Artifact details:

- GCC 14.2.0
- x86_64 Windows, POSIX threads, SEH exceptions, MSVCRT
- MinGW-w64 runtime v12

Representative licensing:

- GCC: GPLv3+
- Applicable GCC runtime libraries: GPLv3 with GCC Runtime Library Exception
- GNU binutils: GPLv3+
- MinGW-w64: component-specific licensing, including ZPL 2.1, Public Domain,
  BSD, LGPL, and other terms where applicable.

Before publishing a release, verify the exact licenses shipped by the selected
toolchain artifact and update this notice if the artifact or its components
change.

Do not state or imply that the downloaded toolchain is licensed under MIT.
