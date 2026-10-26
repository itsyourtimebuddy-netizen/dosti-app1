#!/usr/bin/env bash
# Runs a command, shows its output as usual, and if it fails also publishes the tail of the
# output as a workflow annotation (readable through the GitHub API, not only the web page).
# usage: bash .github/ci_run.sh "<title>" <command> [args...]
title="$1"; shift
set +e
"$@" > ci_output.log 2>&1
code=$?
cat ci_output.log
if [ "$code" -ne 0 ]; then
  # Drop passing-test lines and stack frames so that every failure fits into the annotation.
  msg=$(tr '\r' '\n' < ci_output.log | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
    | grep -v -E '✅|^#[0-9]+ |asynchronous suspension|^$|^\[[= ]*\] [0-9]+%' \
    | tail -c 30000 \
    | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')
  echo "::error title=${title} failed (exit ${code})::${msg}"
fi
exit "$code"
