const std = @import("std");
const RosIdlGenerator = @import("rosidl").RosIdlGenerator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Specify static or dynamic linkage") orelse .dynamic;
    const upstream = b.dependency("rmw_dds_common", .{});

    var rmw_dds_common = std.Build.Step.Compile.create(b, .{
        .root_module = .{
            .target = target,
            .optimize = optimize,
        },
        .name = "rmw_dds_common",
        .kind = .lib,
        .linkage = linkage,
    });

    rmw_dds_common.linkLibCpp();
    rmw_dds_common.addIncludePath(upstream.path("include"));

    const rcutils_dep = b.dependency("rcutils", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    rmw_dds_common.linkLibrary(rcutils_dep.artifact("rcutils"));

    const rcpputils_dep = b.dependency("rcpputils", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    rmw_dds_common.linkLibrary(rcpputils_dep.artifact("rcpputils"));

    const rmw_dep = b.dependency("rmw", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });
    rmw_dds_common.linkLibrary(rmw_dep.artifact("rmw"));

    const rosidl_dep = b.dependency("rosidl", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
    });

    // Generate interfaces that the rmw_dds_common artifact depensd on
    var interface_generator = RosIdlGenerator.create(
        b,
        "rmw_dds_common",
        rosidl_dep,
        rcutils_dep.artifact("rcutils"),
        target,
        optimize,
        linkage,
    );

    interface_generator.addMsgs(&.{
        .{ .path = upstream.path("rmw_dds_common"), .file = "msg/Gid.msg" },
        .{ .path = upstream.path("rmw_dds_common"), .file = "msg/NodeEntitiesInfo.msg" },
        .{ .path = upstream.path("rmw_dds_common"), .file = "msg/ParticipantEntitiesInfo.msg" },
    });

    var test_install = b.addInstallDirectory(.{
        .source_dir = interface_generator.named_write_files.getDirectory(),
        .install_dir = .{ .custom = "rmw_dds_common" },
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&test_install.step);

    b.installArtifact(interface_generator.generator_c.artifact);

    var test_install2 = b.addInstallDirectory(.{
        .source_dir = interface_generator.generator_cpp.artifact.getDirectory(),
        .install_dir = .header,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&test_install2.step);

    b.installArtifact(interface_generator.typesupport_c.artifact);
    b.installArtifact(interface_generator.typesupport_cpp.artifact);
    b.installArtifact(interface_generator.typesupport_introspection_c.artifact);
    b.installArtifact(interface_generator.typesupport_introspection_cpp.artifact);

    // TODO c generator is fully working, still need the other generators (specifically the C++ generators for rmw_dds_common)

    // rmw_dds_common depends on this outside of just interfaces, so name it explicitly
    rmw_dds_common.linkLibrary(rosidl_dep.artifact("rosidl_runtime_c"));
    // TODO default generator is just cmake foo, and only required for generating the interfaces, need to figure out a plan here
    // rmw_dds_common.linkLibrary(rosidl_dep.artifact("rosidl_default_generators"));
    // rmw_dds_common.addIncludePath(rosidl_dep.namedWriteFiles("rosidl_typesupport_interface").getDirectory()); // grab the underlying rosidl dependency for now, until header only libraries are figured out

    // for now name the interface related dependencies explicitly
    // TODO consider a helper that handles this?

    rmw_dds_common.addIncludePath(interface_generator.generator_cpp.artifact.getDirectory());
    rmw_dds_common.addIncludePath(rosidl_dep.namedWriteFiles("rosidl_runtime_cpp").getDirectory());
    rmw_dds_common.addIncludePath(rosidl_dep.namedWriteFiles("rosidl_typesupport_interface").getDirectory());
    rmw_dds_common.addIncludePath(upstream.path("rmw_dds_common/include"));

    // // TODO need interface generation as well, links against the generated rosidl_typesupport_cpp files
    rmw_dds_common.addCSourceFiles(.{
        .root = upstream.path("rmw_dds_common"),
        .files = &.{
            "src/gid_utils.cpp",
            "src/graph_cache.cpp",
            "src/qos.cpp",
            "src/security.cpp",
            "src/time_utils.cpp",
        },
        .flags = &.{"-Wno-deprecated-declarations"},
    });

    rmw_dds_common.installHeadersDirectory(
        upstream.path("rmw_dds_common/include"),
        "",
        .{},
    );
    b.installArtifact(rmw_dds_common);
}
