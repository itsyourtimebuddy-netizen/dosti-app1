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
  msg=$(tail -c 30000 ci_output.log \
    | sed -E 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
    | sed ':a;N;$!ba;s/%/%25/g;s/\r/%0D/g;s/\n/%0A/g')
  echo "::error title=${title} failed (exit ${code})::${msg}"
fi
exit "$code"
