load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//:defs.bzl", "command")

command(
    name = "root_command",
    command = "//tests:echo_hello",
    visibility = ["//tests:__pkg__"],
)

bzl_library(
    name = "defs",
    srcs = ["defs.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        ":command",
        ":multirun",
    ],
)

bzl_library(
    name = "multirun",
    srcs = ["multirun.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "//internal:constants",
        "@bazel_skylib//lib:shell",
    ],
)

bzl_library(
    name = "command",
    srcs = ["command.bzl"],
    visibility = ["//visibility:public"],
    deps = [
        "//internal:constants",
        "@bazel_skylib//lib:shell",
    ],
)
