#!/bin/bash
# This script adds a header to all Dart files in your project.
# It recursively finds all .dart files and prepends the header if it doesn't already exist.

# Define the header using a here-document that includes an extra blank line.
read -r -d '' HEADER << 'EOF'
// Licensed under the Apache License, Version 2.0
// Copyright 2025, Michael Bushe, All rights reserved.


EOF

# Find all .dart files in the current directory and subdirectories
find . -type f -name "*.dart" | while IFS= read -r file; do
    # Check if the header is already present in the file to avoid duplicate headers
    if ! grep -q "Licensed under the Apache License" "$file"; then
        echo "Adding header to $file"
        # Create a temporary file to hold the new content
        tmpfile=$(mktemp)
        # Write the header into the temporary file exactly as defined
        printf "%s\n\n" "$HEADER" > "$tmpfile"
        # Append the original file content
        cat "$file" >> "$tmpfile"
        # Replace the original file with the new file
        mv "$tmpfile" "$file"
    else
        echo "Header already exists in $file. Skipping."
    fi
done
