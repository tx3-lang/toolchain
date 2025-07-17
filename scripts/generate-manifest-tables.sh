#!/bin/bash

# Function to generate table from manifest
generate_table() {
    local manifest_file=$1
    local manifest_name=$2
    
    echo "## $manifest_name"
    echo ""
    echo "| Tool | Version |"
    echo "|------|---------|"
    
    jq -r '.tools[] | "| \(.name) | \(.version) |"' "$manifest_file"
    echo ""
}

# Generate and output tables directly
generate_table "manifest-stable.json" "Stable Manifest"
generate_table "manifest-beta.json" "Beta Manifest"
generate_table "manifest-nightly.json" "Nightly Manifest" 