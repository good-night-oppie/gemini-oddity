#!/bin/bash
# Add SPDX headers to Go files that don't have them

HEADER="// SPDX-FileCopyrightText: 2025 Yongbing Tang and contributors
// SPDX-License-Identifier: MIT"

for file in interfaces/*.go; do
    if [ -f "$file" ] && ! head -n 3 "$file" | grep -q "SPDX-License-Identifier"; then
        echo "Adding SPDX header to: $file"
        # Create temp file with header
        {
            echo "$HEADER"
            echo ""
            cat "$file"
        } > "$file.tmp"
        mv "$file.tmp" "$file"
    fi
done

echo "Done adding SPDX headers"