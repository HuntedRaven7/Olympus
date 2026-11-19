#!/usr/bin/env bash
# Shared helpers for the Hera build scripts.
# shellcheck shell=bash

retry() {
    local attempt=1
    local cmd=("$@")
    until "${cmd[@]}"; do
        if (( attempt >= 3 )); then
            echo "Command failed after ${attempt} attempts: ${cmd[*]}" >&2
            return 1
        fi
        echo "Attempt ${attempt} failed, retrying: ${cmd[*]}" >&2
        sleep 2
        (( attempt++ ))
    done
}
