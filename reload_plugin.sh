#!/usr/bin/env bash

LOG_DONE_LIMIT=12
LOG_CHECK_INTERVAL=0.2

echo "UNLOADING"
tm-remote-build unload -d "$HOME/OpenplanetNext/" --host 172.18.16.1 -p 30000 Editor $@
echo "... sleeping ..."
sleep 2
echo "LOADING"
tm-remote-build load -d "$HOME/OpenplanetNext/" --host 172.18.16.1 -p 30000 -l "$LOG_DONE_LIMIT" -i "$LOG_CHECK_INTERVAL" folder Editor $@
