#!/bin/sh

MODULES=`pactl list short modules`

#echo "$MODULES"
MAKE_GAMING=true
MAKE_CHAT=true
MAKE_MEDIA=true


if [[ ! "$MODULES" =~ sink_name=Gaming? ]]; then
    pactl load-module module-null-sink sink_name=Gaming
fi
if [[ ! "$MODULES" =~ sink_name=Chat? ]]; then
    pactl load-module module-null-sink sink_name=Chat
fi
if [[ ! "$MODULES" =~ sink_name=Media? ]]; then
    pactl load-module module-null-sink sink_name=Media
fi

LINKS=`pw-link -l`
# Gaming
if [[ ! "$LINKS" =~ Gaming:monitor_? ]]; then
    pw-link Gaming:monitor_FL alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FL
    pw-link Gaming:monitor_FR alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FR
fi
# Chat
if [[ ! "$LINKS" =~ Chat:monitor_? ]]; then
    pw-link Chat:monitor_FL alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FL
    pw-link Chat:monitor_FR alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FR
fi
# Media
if [[ ! "$LINKS" =~ Media:monitor_? ]]; then
    pw-link Media:monitor_FL alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FL
    pw-link Media:monitor_FR alsa_output.usb-SteelSeries_Arctis_Nova_Pro_Wireless-00.analog-stereo:playback_FR
fi
