load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_python//python:defs.bzl", "py_binary")

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
    name = "binary_args_env",
    srcs = ["binary_args_env.bzl"],
    visibility = ["//:__pkg__"],
)

bzl_library(
    name = "constants",
    srcs = ["constants.bzl"],
    visibility = ["//:__pkg__"],
)
