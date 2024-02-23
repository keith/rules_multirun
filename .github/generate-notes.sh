#!/bin/bash

set -euo pipefail

readonly new_version=$1
readonly release_archive="rules_multirun.$new_version.tar.gz"

sha=$(shasum -a 256 "$release_archive" | cut -d " " -f1)

cat <<EOF
## What's Changed

TODO

### MODULE.bazel Snippet

\`\`\`bzl
bazel_dep(name = "rules_multirun", version = "$new_version")
\`\`\`

### Workspace Snippet

\`\`\`bzl
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_multirun",
    sha256 = "$sha",
    url = "https://github.com/keith/rules_multirun/releases/download/$new_version/rules_multirun.$new_version.tar.gz",
)
\`\`\`
EOF
