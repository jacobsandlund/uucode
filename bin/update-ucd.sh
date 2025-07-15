#!/bin/bash

UNICODE_VERSION="16.0.0"
BASE_URL="https://www.unicode.org/Public/${UNICODE_VERSION}/ucd"
TARGET_DIR="data/ucd"

mkdir -p "$TARGET_DIR"

echo "Updating Unicode Character Database version $UNICODE_VERSION..."

UCD_FILES=(
    "CaseFolding.txt"
    "DerivedCoreProperties.txt"
    "auxiliary/GraphemeBreakProperty.txt"
    "UnicodeData.txt"
    "emoji/emoji-data.txt"
    "extracted/DerivedEastAsianWidth.txt"
)

for file in "${UCD_FILES[@]}"; do
    file_url="${BASE_URL}/${file}"
    target_path="${TARGET_DIR}/${file}"

    mkdir -p "$(dirname "$target_path")"

    curl -L -o "$target_path" "$file_url"
done

echo
echo
echo "Next, see the note towards the top of 'src/build/Ucd.zig' and switch to"
echo "using these increased capacities temporarily (commenting out the old"
echo "ones):"
echo
echo "const string_pool_capacity = 10_000_000;"
echo "const code_point_pool_capacity = 100_000;"
echo
echo "Then run 'zig build' and the error messages will print out the new"
echo "constants to be used at the top of 'src/build/Ucd.zig', and"
echo "'src/type.zig'."
echo
