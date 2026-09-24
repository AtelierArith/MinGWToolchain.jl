using Test
using MinGWToolchain
using Libdl

const SUPPORTED = Sys.iswindows() && Sys.ARCH == :x86_64

if SUPPORTED
    @eval using CMake_jll, GNUMake_jll, Ninja_jll
end

const HELLO_C = """
#include <stdio.h>
int main(void) {
    puts("hello from C");
    return 0;
}
"""

@testset "MinGWToolchain" begin
    @testset "platform behavior" begin
        if SUPPORTED
            @test isdir(toolchain_root())
            @test isdir(bindir())
            @test isfile(gcc())
            @test isfile(gxx())
            @test isfile(gfortran())
            @test is_available("gcc")
            @test is_available("windres")
            @test toolchain_version() >= v"14"
            @test tool("gcc") == gcc()
            @test tool("gcc.exe") == gcc()
        else
            @test_throws MinGWToolchain.UnsupportedPlatformError toolchain_root()
            @test_throws MinGWToolchain.UnsupportedPlatformError bindir()
            @test_throws MinGWToolchain.UnsupportedPlatformError gcc()
            @test_throws MinGWToolchain.UnsupportedPlatformError gfortran()
        end
    end

    @testset "tool lookup errors" begin
        if SUPPORTED
            @test !is_available("definitely-not-a-real-tool")
            @test_throws MinGWToolchain.ToolNotFoundError tool("definitely-not-a-real-tool")
        end
    end

    if SUPPORTED
        build_tools_path = join(
            (dirname(Ninja_jll.ninja_path), dirname(GNUMake_jll.make_path)),
            ';',
        )

        function with_build_tools(f)
            return with_toolchain() do
                Base.withenv("PATH" => string(build_tools_path, ';', ENV["PATH"])) do
                    f()
                end
            end
        end

        # CMake integration defaults to the Ninja generator. Set
        # MINGWTOOLCHAIN_CMAKE_GENERATOR to "mingw-makefiles" (or "both") to
        # exercise the `-G "MinGW Makefiles"` generator as well.
        function cmake_generators()
            spec = lowercase(Base.strip(get(ENV, "MINGWTOOLCHAIN_CMAKE_GENERATOR", "ninja")))
            spec == "both" && return (:ninja, :mingw_makefiles)
            spec in ("mingw", "mingw-makefiles", "mingw makefiles") && return (:mingw_makefiles,)
            return (:ninja,)
        end

        function cmake_generator_flag(generator)
            generator === :ninja && return "Ninja"
            generator === :mingw_makefiles && return "MinGW Makefiles"
            throw(ArgumentError("unknown CMake generator: $(generator)"))
        end

        @testset "GNU Make integration" begin
            mktempdir() do dir
                cd(dir) do
                    write("hello.c", HELLO_C)
                    write(
                        "Makefile",
                        "all: hello_make.exe\n\n" *
                        "hello_make.exe: hello.c\n" *
                        "\t\$(CC) hello.c -o hello_make.exe\n",
                    )

                    out = with_build_tools() do
                        run(GNUMake_jll.make())
                        read(`./hello_make.exe`, String)
                    end
                    @test occursin("hello from C", out)
                end
            end
        end

        @testset "CMake integration ($generator)" for generator in cmake_generators()
            mktempdir() do dir
                cd(dir) do
                    write("hello.c", HELLO_C)
                    write("CMakeLists.txt", """
                    cmake_minimum_required(VERSION 3.20)
                    project(hello_cmake C)
                    add_executable(hello_cmake hello.c)
                    """)

                    out = with_build_tools() do
                        cmake = CMake_jll.cmake()
                        args = [
                            "-S",
                            ".",
                            "-B",
                            "build",
                            "-G",
                            cmake_generator_flag(generator),
                            "-DCMAKE_C_COMPILER=$(gcc())",
                        ]
                        if generator === :mingw_makefiles
                            push!(args, "-DCMAKE_MAKE_PROGRAM=$(GNUMake_jll.make_path)")
                        end
                        run(`$cmake $args`)
                        run(`$cmake --build build`)
                        read(`./build/hello_cmake.exe`, String)
                    end
                    @test occursin("hello from C", out)
                end
            end
        end

        @testset "C/C++/Fortran compile and run" begin
            mktempdir() do dir
                cd(dir) do
                    write("hello.c", """
                    #include <stdio.h>
                    int main(void) {
                        puts("hello from C");
                        return 0;
                    }
                    """)

                    write("hello.cpp", """
                    #include <iostream>
                    int main() {
                        std::cout << "hello from C++\\n";
                        return 0;
                    }
                    """)

                    write("hello.f90", """
                    program hello
                        print *, "hello from Fortran"
                    end program hello
                    """)

                    with_toolchain() do
                        run(`$(gcc()) hello.c -o hello_c.exe`)
                        @test occursin("hello from C", read(`./hello_c.exe`, String))

                        run(`$(gxx()) hello.cpp -o hello_cpp.exe`)
                        @test occursin("hello from C++", read(`./hello_cpp.exe`, String))

                        run(`$(gfortran()) hello.f90 -o hello_fortran.exe`)
                        @test occursin("hello from Fortran", read(`./hello_fortran.exe`, String))
                    end
                end
            end
        end

        @testset "Fortran shared library + ccall" begin
            mktempdir() do dir
                cd(dir) do
                    write("add_one.f90", """
                    function add_one(x) bind(C, name="add_one") result(y)
                        use iso_c_binding
                        real(c_double), value :: x
                        real(c_double) :: y
                        y = x + 1.0d0
                    end function add_one
                    """)

                    with_toolchain() do
                        run(`$(gfortran()) -shared add_one.f90 -o add_one.dll`)
                        @test isfile(joinpath(dir, "add_one.dll"))

                        handle = Libdl.dlopen(joinpath(dir, "add_one.dll"))
                        try
                            fptr = Libdl.dlsym(handle, :add_one)
                            s = ccall(fptr, Cdouble, (Cdouble,), 41.0)
                            @test s == 42.0
                        finally
                            Libdl.dlclose(handle)
                        end
                    end
                end
            end
        end

        @testset "with_toolchain environment" begin
            old_path = get(ENV, "PATH", nothing)
            had_cc = haskey(ENV, "CC")
            old_cc = get(ENV, "CC", nothing)

            with_toolchain() do
                @test first(split(ENV["PATH"], ';')) == bindir()
                @test ENV["CC"] == gcc()
                @test ENV["CXX"] == gxx()
                @test ENV["FC"] == gfortran()
                @test ENV["AR"] == ar()
                @test ENV["RANLIB"] == ranlib()
                @test ENV["RC"] == windres()
            end

            @test get(ENV, "PATH", nothing) == old_path
            @test haskey(ENV, "CC") == had_cc
            had_cc && @test get(ENV, "CC", nothing) == old_cc

            with_toolchain(set_compiler_vars=false) do
                @test first(split(ENV["PATH"], ';')) == bindir()
                @test haskey(ENV, "CC") == had_cc
            end
            @test get(ENV, "PATH", nothing) == old_path
        end

        @testset "environment restored on error" begin
            old_path = get(ENV, "PATH", nothing)
            @test_throws ErrorException with_toolchain() do
                error("boom")
            end
            @test get(ENV, "PATH", nothing) == old_path
        end
    end
end
