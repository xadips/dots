#!/bin/bash
LAYOUT=$(hyprctl devices | rg -A 2 'duckychannel-international-co.,-ltd.-ducky-keyboard-1' | rg keymap | awk '{ print $3 }')
[[ "$LAYOUT" == "English" ]] && echo "us" || echo "lt"
