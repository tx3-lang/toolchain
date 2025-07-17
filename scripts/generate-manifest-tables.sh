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

# Generate tables for each manifest
stable_table=$(generate_table "manifest-stable.json" "Stable Manifest")
beta_table=$(generate_table "manifest-beta.json" "Beta Manifest")
nightly_table=$(generate_table "manifest-nightly.json" "Nightly Manifest")

# Combine all tables
combined_tables="$stable_table$beta_table$nightly_table"

echo "$combined_tables" 