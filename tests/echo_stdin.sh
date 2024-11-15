#!/bin/bash

std_in=$(</dev/stdin)

printf 'From stdin: %s\n' "${std_in}"

exit 0
