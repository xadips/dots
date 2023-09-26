#!/bin/bash
[[ $(nmcli con show --active | grep wg) ]] && echo "<span color='#2bab1a'></span>" || echo "<span color='#bf616a'></span>" 