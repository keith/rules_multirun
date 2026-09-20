load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_python//python:defs.bzl", "py_binary", "py_test")

py_binary(
    name = "multirun",
    srcs = ["multirun.py"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        "@rules_python//python/runfiles",
    ],
)

bzl_library(
    name = "constants",
    srcs = ["constants.bzl"],
    visibility = ["//:__pkg__"],
)

py_test(
    name = "windows_process_test",
    srcs = [
        "multirun.py",
        "windows_process_test.py",
    ],
    target_compatible_with = ["@platforms//os:windows"],
    deps = ["@rules_python//python/runfiles"],
)
