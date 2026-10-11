using Test
using MinGWToolchain
using Libdl

const SUPPORTED = Sys.iswindows() && Sys.ARCH == :x86_64

function _find_libexec(name::AbstractString)
    root = joinpath(toolchain_root(), "libexec")
    isdir(root) || return nothing
    for (dir, _, files) in walkdir(root)
        name in files && return joinpath(dir, name)
    end
    return nothing
end

function _can_spawn(exe::AbstractString)
    try
        run(pipeline(Cmd(`$exe --version`; ignorestatus=true); stdout=devnull, stderr=devnull))
        return true
    catch
        return false
    end
end

function _run_compiled(exe::AbstractString, needle::AbstractString)
    @test isfile(exe)
    output = try
        read(`./$exe`, String)
    catch e
        e isa Base.IOError || rethrow()
        @test_skip "$exe could not be spawned (Application Control)"
        return
    end
    @test occursin(needle, output)
end

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
            @test tool("gcc") == joinpath(bindir(), "gcc.exe")
            @test tool("gcc.exe") == tool("gcc")
            @test gcc() == tool("x86_64-w64-mingw32-gcc") || gcc() == tool("gcc")
            @test gxx() == tool("x86_64-w64-mingw32-g++") || gxx() == tool("g++")
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
                        _run_compiled("hello_c.exe", "hello from C")

                        # Application Control policies may block cc1plus.exe by
                        # filename even when the g++ driver itself is runnable.
                        cc1plus = _find_libexec("cc1plus.exe")
                        if cc1plus !== nothing && _can_spawn(cc1plus)
                            run(`$(gxx()) hello.cpp -o hello_cpp.exe`)
                            _run_compiled("hello_cpp.exe", "hello from C++")
                        else
                            @test_skip "C++ frontend (cc1plus.exe) is blocked by Application Control"
                        end

                        run(`$(gfortran()) hello.f90 -o hello_fortran.exe`)
                        _run_compiled("hello_fortran.exe", "hello from Fortran")
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

        @testset "C shared library + ccall" begin
            mktempdir() do dir
                cd(dir) do
                    write("add_one_c.c", """
                    double add_one_c(double x) {
                        return x + 1.0;
                    }
                    """)

                    with_toolchain() do
                        run(`$(gcc()) -shared -Wl,--export-all-symbols add_one_c.c -o add_one_c.dll`)
                        @test isfile(joinpath(dir, "add_one_c.dll"))

                        handle = Libdl.dlopen(joinpath(dir, "add_one_c.dll"))
                        try
                            fptr = Libdl.dlsym(handle, :add_one_c)
                            @test ccall(fptr, Cdouble, (Cdouble,), 41.0) == 42.0
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
