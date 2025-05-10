#!/usr/bin/env bash

tm-remote-build getlogs -d "$HOME/OpenplanetNext/" --host 172.18.16.1 -p 30000 Editor $@
