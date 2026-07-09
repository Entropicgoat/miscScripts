#!/bin/bash

# Find current rotation
LINE=`hyprctl monitors | grep DP-2 -A 11`
ROTATION=${LINE: -1}

# Conditionally rotate
if [[ "$ROTATION" == 3 ]]; then
    hyprctl keyword monitor DP-2,preferred,auto-right,2
else
    hyprctl keyword monitor DP-2,preferred,auto-right,2,transform,3
fi

