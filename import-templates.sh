#!/bin/bash

# This script imports n8n workflow templates using the provided API key

# Set the API key
N8N_API_KEY=$(cat .n8n_api_key)

# Directory containing the template files
TEMPLATES_DIR="./workflows/templates"

# Function for logging
function log {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting template import with provided API key..."

# Import each template
for template in "$TEMPLATES_DIR"/*.json; do
    if [ -f "$template" ]; then
        filename=$(basename -- "$template")
        log "Importing template: $filename"
        
        result=$(curl -X POST "http://localhost:5678/rest/workflows" \
          -H "X-N8N-API-KEY: $N8N_API_KEY" \
          -H "Content-Type: application/json" \
          -d @"$template" -s)
        
        # Check if import was successful
        if echo "$result" | grep -q "\"id\":"; then
            log "✅ Successfully imported $filename"
        else
            log "❌ Failed to import $filename: $result"
        fi
    fi
done

log "Template import completed!"
