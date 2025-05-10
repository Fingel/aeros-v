const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const kernel = b.addExecutable(.{
        .name = "aeros.elf",
        .root_source_file = b.path("src/kernel.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .optimize = .ReleaseSmall,
        .strip = false,
    });
    kernel.entry = .disabled;

    kernel.setLinkerScript(b.path("src/kernel.ld"));

    const shell = b.addExecutable(.{
        .name = "shell.elf",
        .root_source_file = b.path("src/shell.zig"),
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .riscv32,
            .os_tag = .freestanding,
            .abi = .none,
        }),
        .optimize = .ReleaseSmall,
        .strip = false,
    });

    shell.entry = .disabled;
    shell.setLinkerScript(b.path("src/user.ld"));
    b.installArtifact(shell);

    const bin = b.addObjCopy(shell.getEmittedBin(), .{
        .basename = "shell.bin",
        .format = .bin,
    });

    kernel.root_module.addAnonymousImport("shell.bin", .{
        .root_source_file = bin.getOutput(),
    });

    // const elf2bin = b.addSystemCommand(&.{
    //     "llvm-objcopy",

    //     "--set-section-flags",
    //     ".bss=alloc,contents",
    //     "-O",
    //     "binary",
    // });

    // elf2bin.addArtifactArg(shell);
    // const bin = elf2bin.addOutputFileArg("shell.bin");

    // const bin2o = b.addSystemCommand(&.{
    //     "llvm-objcopy",
    //     "-Ibinary",
    //     "-Oelf32-littleriscv",
    //     // "shell.bin",
    //     // "shell.bin.o",
    // });

    // bin2o.addFileArg(bin);
    // const shell_obj = bin2o.addOutputFileArg("shell.bin.o");
    // _ = shell_obj;

    // kernel.addObjectFile(shell_obj);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(kernel);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addSystemCommand(&.{"qemu-system-riscv32"});

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    run_cmd.addArgs(&.{
        "-machine",    "virt",
        "-bios",       "default",
        "-serial",     "mon:stdio",
        "--no-reboot", "-nographic",
        "-kernel",
    });

    run_cmd.addArtifactArg(kernel);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run Qemu");
    run_step.dependOn(&run_cmd.step);
}
