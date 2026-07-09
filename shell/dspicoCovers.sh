#!/usr/bin/env bash
#
# dspicoCovers.sh
#
# Finds mounted removable media (USB sticks / SD card readers), lets the user
# pick one, verifies it looks like a DSpico (Pico Launcher) card, then
# downloads GameTDB box art for every .nds ROM on it so covers display in the
# launcher on the DS/3DS.
#
# Covers are written as 8-bit 128x96 BMPs to /_pico/covers/nds/<GAMECODE>.bmp
# (art occupies the left 106x96; the right 22px are black padding, per
# pico-launcher docs/Covers.md). If /_nds/TWiLightMenu exists on the card,
# 128x115 PNGs are also written to its boxart directory.
#
# Usage: dspicoCovers.sh [path-to-card]
#   With no argument, scans for mounted removable volumes and prompts.
#
# Covers that can't be found on GameTDB are reported with their game code and
# the path where a hand-picked image can be dropped (.png/.jpg/.jpeg/.webp,
# same basename as the missing .bmp). On the next run such images are found
# and converted before GameTDB is consulted. ROMs without a valid game code
# (homebrew) use Pico Launcher's filename-matched covers in /_pico/covers/user/.
#
# Requires: curl, ImageMagick (macOS: brew install imagemagick;
#           Linux: apt/dnf/pacman install imagemagick)

set -u

REGION_FALLBACKS="EN US JA EU FR DE IT ES NL PT"
DSPICO_MARKERS="_picoboot.nds _pico/picoLoader7.bin _pico/picoLoader9.bin"

err() { printf 'Error: %s\n' "$*" >&2; }

# --- dependency checks -------------------------------------------------------
if command -v magick >/dev/null 2>&1; then
    MAGICK=magick
    IDENTIFY='magick identify'
elif command -v convert >/dev/null 2>&1; then
    MAGICK=convert
    IDENTIFY=identify
else
    err "ImageMagick is required to produce the 8-bit BMP covers DSpico expects."
    err "Install it with: brew install imagemagick (macOS),"
    err "  sudo apt install imagemagick (Debian/Ubuntu), or your distro's package manager."
    exit 1
fi
command -v curl >/dev/null 2>&1 || { err "curl is required."; exit 1; }

# --- pick the card -----------------------------------------------------------
find_removable_volumes() {
    VOLUMES=()
    case "$(uname)" in
        Darwin)
            local vol
            for vol in /Volumes/*; do
                [ -d "$vol" ] || continue
                diskutil info "$vol" 2>/dev/null \
                    | grep -qE 'Device Location: *External|Removable Media: *Removable' \
                    && VOLUMES+=("$vol")
            done
            ;;
        *)
            local vol
            for vol in /media/"$USER"/* /run/media/"$USER"/*; do
                [ -d "$vol" ] && VOLUMES+=("$vol")
            done
            ;;
    esac
}

if [ $# -ge 1 ]; then
    CARD=$1
    [ -d "$CARD" ] || { err "$CARD is not a directory."; exit 1; }
else
    find_removable_volumes
    if [ "${#VOLUMES[@]}" -eq 0 ]; then
        err "No removable volumes found. Insert the DSpico's microSD card and try again."
        exit 1
    fi
    printf 'Removable volumes found:\n'
    PS3='Select the DSpico card (number): '
    select CARD in "${VOLUMES[@]}"; do
        [ -n "${CARD:-}" ] && break
        printf 'Invalid selection.\n'
    done
    [ -n "${CARD:-}" ] || exit 1
fi
CARD=${CARD%/}
printf 'Using: %s\n' "$CARD"

# --- confirm it is a DSpico card ---------------------------------------------
missing_markers=""
for f in $DSPICO_MARKERS; do
    [ -e "$CARD/$f" ] || missing_markers="$missing_markers $f"
done
if [ -n "$missing_markers" ]; then
    printf 'Warning: this does not look like a DSpico (Pico Launcher) card.\n'
    printf 'Missing:\n'
    printf '  %s\n' $missing_markers
    printf 'Continue anyway? [y/N] '
    read -r reply
    case "$reply" in
        y|Y|yes|YES) ;;
        *) printf 'Aborting.\n'; exit 1 ;;
    esac
else
    printf 'DSpico card confirmed (found: %s).\n' "$DSPICO_MARKERS"
fi

# --- helpers -----------------------------------------------------------------
tmpdir=$(mktemp -d) || exit 1
trap 'rm -rf "$tmpdir"' EXIT

rom_header_code() {  # $1 = rom path; prints the header's game-code bytes (printable chars only)
    dd if="$1" bs=4 skip=3 count=1 2>/dev/null | LC_ALL=C tr -cd '[:print:]'
}

find_local_image() {  # $1 = dir, $2 = basename; prints the path of a user-supplied image
    local ext
    for ext in png PNG jpg JPG jpeg JPEG webp WEBP; do
        [ -f "$1/$2.$ext" ] && { printf '%s' "$1/$2.$ext"; return 0; }
    done
    return 1
}

make_cover() {  # $1 = source image, $2 = dest bmp, $3 = boxart basename, $4 = TWL boxart dir ("" = skip)
    # Pico Launcher: 8bpp BMP, 128x96 canvas, art in the left 106x96.
    "$MAGICK" "$1" -alpha remove -alpha off -resize '106x96!' \
        -background black -gravity NorthWest -extent 128x96 \
        -colors 256 -type Palette -compress none BMP3:"$2" 2>/dev/null || return 1
    # ImageMagick writes 1/4bpp BMPs when the art has <=16 colors, but the
    # launcher only accepts 8bpp. Force a >16-color palette by hiding a
    # gradient in the right 22px, which the launcher ignores.
    if [ "$($IDENTIFY -format '%z' "$2" 2>/dev/null)" != 8 ]; then
        "$MAGICK" "$2" \( -size 22x96 gradient: \) -geometry +106+0 -composite \
            -colors 256 -type Palette -depth 8 -compress none BMP3:"$2" 2>/dev/null || return 1
    fi
    # TWiLight Menu++ (if installed on the card): 128x115 PNG boxart.
    if [ -n "$4" ] && [ ! -e "$4/$3.png" ]; then
        "$MAGICK" "$1" -alpha remove -alpha off -resize 128x115 \
            "$4/$3.png" 2>/dev/null
    fi
    return 0
}

fetch_cover() {  # $1 = game code, $2 = output file
    local code=$1 out=$2 regions tried="" r url
    # Guess the region from the 4th character of the game code, then fall back.
    case "${code:3:1}" in
        E) regions="US" ;;  J) regions="JA" ;;  P|V|X|Y|Z) regions="EN" ;;
        F) regions="FR" ;;  D) regions="DE" ;;  I) regions="IT" ;;
        S) regions="ES" ;;  H) regions="NL" ;;  K) regions="KO" ;;
        U) regions="AU" ;;  *) regions="" ;;
    esac
    for r in $regions $REGION_FALLBACKS; do
        case " $tried " in *" $r "*) continue ;; esac
        tried="$tried $r"
        for url in \
            "https://art.gametdb.com/ds/cover/$r/$code.png" \
            "https://art.gametdb.com/ds/cover/$r/$code.jpg" \
            "https://art.gametdb.com/ds/coverS/$r/$code.png"; do
            curl -fsSL --connect-timeout 10 --max-time 30 -o "$out" "$url" 2>/dev/null && return 0
        done
        sleep 0.2  # be polite to GameTDB between fallback regions
    done
    return 1
}

# --- process ROMs -------------------------------------------------------------
covers_dir="$CARD/_pico/covers/nds"
user_covers_dir="$CARD/_pico/covers/user"
mkdir -p "$covers_dir" "$user_covers_dir" || { err "cannot create cover directories"; exit 1; }
twl_boxart=""
if [ -d "$CARD/_nds/TWiLightMenu" ]; then
    twl_boxart="$CARD/_nds/TWiLightMenu/boxart"
    mkdir -p "$twl_boxart"
fi

downloaded=0 converted=0 skipped=0 missing=0 found=0

while IFS= read -r -d '' rom; do
    found=$((found + 1))
    name=$(basename "$rom")

    header=$(rom_header_code "$rom")
    if printf '%s' "$header" | grep -qE '^[A-Z0-9]{4}$'; then
        code=$header
        cover_dir=$covers_dir
        key=$code
        label="[$code]"
    else
        # No usable game code (homebrew): Pico Launcher falls back to
        # filename-matched covers in _pico/covers/user/.
        code=""
        cover_dir=$user_covers_dir
        key=$name
        label="[header: '$header']"
    fi

    dest="$cover_dir/$key.bmp"
    if [ -e "$dest" ]; then
        printf '%-40s  %s cover already present\n' "$name" "$label"
        skipped=$((skipped + 1))
        continue
    fi

    # A hand-picked image placed where the .bmp belongs takes precedence
    # over GameTDB, so misses can be fixed manually and the script re-run.
    if src=$(find_local_image "$cover_dir" "$key"); then
        if make_cover "$src" "$dest" "$key" "$twl_boxart"; then
            printf '%-40s  %s converted local image %s\n' "$name" "$label" "$(basename "$src")"
            converted=$((converted + 1))
        else
            printf '%-40s  %s could not convert local image %s\n' "$name" "$label" "$(basename "$src")"
            missing=$((missing + 1))
        fi
        continue
    fi

    if [ -z "$code" ]; then
        printf '%-40s  %s no game code to look up; place a cover at %s.png (or .jpg) and re-run\n' \
            "$name" "$label" "$cover_dir/$key"
        missing=$((missing + 1))
        continue
    fi

    raw="$tmpdir/$code"
    if ! fetch_cover "$code" "$raw"; then
        printf '%-40s  %s not on GameTDB; place a cover at %s.png (or .jpg) and re-run\n' \
            "$name" "$label" "$cover_dir/$key"
        missing=$((missing + 1))
        continue
    fi

    if ! make_cover "$raw" "$dest" "$key" "$twl_boxart"; then
        printf '%-40s  %s downloaded but conversion failed\n' "$name" "$label"
        missing=$((missing + 1))
        continue
    fi

    printf '%-40s  %s cover downloaded\n' "$name" "$label"
    downloaded=$((downloaded + 1))
done < <(find "$CARD" -type f -iname '*.nds' \
            ! -name '._*' ! -name '_picoboot.nds' ! -path '*/.*' \
            ! -path '*/_pico/*' ! -path '*/_nds/*' -print0)

# --- summary -------------------------------------------------------------------
printf '\n%d ROM(s) found: %d downloaded, %d converted from local images, %d already present, %d still missing.\n' \
    "$found" "$downloaded" "$converted" "$skipped" "$missing"
[ "$found" -eq 0 ] && printf 'No .nds files found on %s.\n' "$CARD"
# Non-zero exit if any covers are still missing, so scripted runs can detect it.
[ "$missing" -eq 0 ] || exit 1
exit 0
