#!/bin/bash

std_in=$(</dev/stdin)

printf 'From stdin2: %s\n' "${std_in}"

exit 0