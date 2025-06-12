load("@bazel_skylib//rules:diff_test.bzl", "diff_test")
load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@io_bazel_stardoc//stardoc:stardoc.bzl", "stardoc")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

_DOC_SRCS = [
    "defs",
]

[
    stardoc(
        name = file + "_doc",
        out = file + ".gen.md",
        input = "//:{}.bzl".format(file),
        tags = ["no-cache"],
        deps = [
            "//:" + file,
        ],
    )
    for file in _DOC_SRCS
]

write_file(
    name = "gen_update",
    out = "update.sh",
    content = [
        "#!/usr/bin/env bash",
        "set -euo pipefail",
    ] + [
        'cp -fv doc/{file}.gen.md "$BUILD_WORKSPACE_DIRECTORY/doc/README.md"'.format(
            file = file,
        )
        for file in _DOC_SRCS
    ],
)

sh_binary(
    name = "update",
    srcs = ["update.sh"],
    data = [file + ".gen.md" for file in _DOC_SRCS],
)

[
    diff_test(
        name = "check_" + file,
        failure_message = "\nPlease update the docs by running\n    bazel run //doc:update",
        file1 = file + ".gen.md",
        file2 = "README.md",
    )
    for file in _DOC_SRCS
]
