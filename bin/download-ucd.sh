#!/bin/bash

UNICODE_VERSION="16.0.0"
BASE_URL="https://www.unicode.org/Public/${UNICODE_VERSION}/ucd"
TARGET_DIR="data/ucd"

mkdir -p "$TARGET_DIR"

echo "Downloading Unicode Character Database version $UNICODE_VERSION..."

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
