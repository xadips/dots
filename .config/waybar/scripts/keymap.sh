#!/bin/bash
[[ $(hyprctl devices | rg -A 2 'duckychannel-international-co.,-ltd.-ducky-keyboard' | grep Lithuanian) ]] && echo "lt" || echo "us"
