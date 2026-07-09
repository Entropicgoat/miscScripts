#!/bin/bash

# Set Hyprland socket
export HYPRLAND_INSTANCE_SIGNATURE=$(ls $XDG_RUNTIME_DIR/hypr/ | head -n1)

# Use Sunshine's client variables or default values
WIDTH=${SUNSHINE_CLIENT_WIDTH:-5120}
HEIGHT=${SUNSHINE_CLIENT_HEIGHT:-1440}
FPS=${SUNSHINE_CLIENT_FPS:-239.76}

if [[ "${DEFAULT:-}" = true ]]; then
    WIDTH=5120
    HEIGHT=1440
    FPS=239.76
fi

# Change monitor resolution
hyprctl keyword monitor DP-3,${WIDTH}x${HEIGHT}@${FPS},auto,1
