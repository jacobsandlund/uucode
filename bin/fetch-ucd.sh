#!/bin/bash

set -euo pipefail

version="18.0.0"

base_url="https://www.unicode.org/Public/${version}/ucd"
emoji_url="https://www.unicode.org/Public/${version}/emoji"

cd "$(dirname "$0")/.."

download_dir=$(mktemp -d)
trap 'rm -rf "$download_dir"' EXIT
mkdir -p "$download_dir/ucd/emoji" "$download_dir/ucd/Unihan"

curl -fLSs -o "$download_dir/ucd.zip" "${base_url}/UCD.zip"
unzip -q "$download_dir/ucd.zip" -d "$download_dir/ucd"

for file in emoji-sequences.txt emoji-test.txt emoji-zwj-sequences.txt; do
    curl -fLSs -o "$download_dir/ucd/emoji/$file" "${emoji_url}/$file"
done

curl -fLSs -o "$download_dir/unihan.zip" "${base_url}/Unihan.zip"
unzip -q "$download_dir/unihan.zip" -d "$download_dir/ucd/Unihan"

# Replace ucd/ wholesale so files dropped upstream don't linger, keeping only
# our .gitignore.
cp ucd/.gitignore "$download_dir/ucd/.gitignore"
rm -rf ucd
mv "$download_dir/ucd" ucd

echo
echo "########################################################################"
echo
echo "Done fetching UCD files"
echo
echo "Explicitly add any new files to start parsing to the list of .gitignore"
echo "exceptions. Add a '#' to comment them out, appending '(used)' at the end."
echo
echo "Next, flip the 'is_updating_ucd' flag in 'src/config.zig' to true, and"
echo "'zig build test' once, updating 'src/fields.zig' if it needs"
echo "changing, before flipping 'is_updating_ucd' back to false."
echo
