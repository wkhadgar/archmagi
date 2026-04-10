#!/bin/bash

exec tuigreet \
    --cmd start-hyprland \
    --issue \
    --time \
    --time-format '%H:%M:%S  //  %A %d %B' \
    --width 60 \
    --greet-align center \
    --asterisks \
    --theme 'body=black;container=black;border=yellow;prompt=white;greet=yellow;input=yellow;action=white;button=yellow'
