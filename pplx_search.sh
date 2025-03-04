#!/bin/bash

# pplx_search.sh - Terminal client for Perplexity API with improved error handling

# Configuration file location
CONFIG_FILE="$HOME/.pplx_search.conf"
DEBUG_MODE=false
DEFAULT_MODEL="sonar"

# Function to display usage information
usage() {
    echo "Perplexity API Terminal Client"
    echo ""
    echo "Usage:"
    echo "  pplx search \"your search query\"                    # Perform a search"
    echo "  pplx search -m MODEL \"your search query\"           # Search with specific model"
    echo "  pplx configure                                     # Set up your API key"
    echo "  pplx verify                                        # Verify your API key works"
    echo "  pplx debug \"your search query\"                     # Search with debug output"
    echo "  pplx raw \"your search query\"                       # Show raw API response"
    echo "  pplx models                                        # List available models"
    echo "  pplx export [-f FORMAT] [-o FILE] \"query\"           # Export results to a file"
    echo "  pplx help                                          # Show this help message"
    echo ""
    echo "Export formats:"
    echo "  -f md    # Markdown format (default)"
    echo "  -f txt   # Plain text format"
    echo "  -f pdf   # PDF format (requires pandoc or wkhtmltopdf)"
    echo ""
    echo "For available models, run 'pplx models'"
}

# Function to list available models
list_models() {
    echo "=== Perplexity AI Models ==="
    echo "Model               | Context Length | Type"
    echo "--------------------|--------------|--------------"
    echo "sonar-deep-research | 128k         | Chat Completion"
    echo "sonar-reasoning-pro | 128k         | Chat Completion"
    echo "sonar-reasoning     | 128k         | Chat Completion"
    echo "sonar-pro           | 200k         | Chat Completion"
    echo "sonar               | 128k         | Chat Completion"
    echo "r1-1776             | 128k         | Chat Completion"
    echo ""
    echo "Default model: $DEFAULT_MODEL"
    echo ""
    echo "For up-to-date model information, visit: https://docs.perplexity.ai"
}

# Function to configure the API key
configure() {
    echo "Enter your Perplexity API Key (should start with 'pplx-'):"
    read -s API_KEY
    
    # Basic validation
    if [[ ! "$API_KEY" =~ ^pplx- ]]; then
        echo "Warning: API key doesn't start with 'pplx-'. This may not be correct."
        echo "Continue anyway? (y/n)"
        read CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
            echo "Configuration canceled."
            return 1
        fi
    fi
    
    echo "API_KEY=$API_KEY" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "API key saved to $CONFIG_FILE"
    
    echo "Would you like to verify the API key works? (y/n)"
    read VERIFY
    if [[ "$VERIFY" =~ ^[Yy] ]]; then
        verify_api_key
    fi
}

# Function to verify API key works
verify_api_key() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No API key configured. Run 'pplx configure' first."
        return 1
    fi
    
    source "$CONFIG_FILE"
    
    if [ -z "$API_KEY" ]; then
        echo "Error: API key is empty. Run 'pplx configure' to set a valid key."
        return 1
    fi

    echo "Testing API key with a simple request..."
    
    # Create temporary file for the response
    TEMP_FILE=$(mktemp)
    
    # Simple test JSON payload
    JSON_PAYLOAD=$(cat <<-END
{
  "model": "$DEFAULT_MODEL",
  "messages": [
    {
      "role": "user",
      "content": "Hello, just testing the API connection."
    }
  ]
}
END
)

    # Make API request with -i flag to include headers
    curl -i -s -X POST "https://api.perplexity.ai/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$JSON_PAYLOAD" > "$TEMP_FILE"
    
    # Check for 401 error
    if grep -q "401 Authorization Required" "$TEMP_FILE"; then
        echo "❌ API key verification FAILED: 401 Authorization Required"
        echo ""
        echo "This error means your API key is invalid or expired. Please check that:"
        echo "1. You have an active Perplexity API subscription"
        echo "2. You've copied the full API key correctly from your Perplexity account"
        echo "3. The API key begins with 'pplx-'"
        echo ""
        echo "Visit https://www.perplexity.ai/settings/api to manage your API keys"
        rm "$TEMP_FILE" 2>/dev/null
        return 1
    fi
    
    # Check if we got JSON back (successful response)
    if grep -q "\"choices\":" "$TEMP_FILE"; then
        echo "✅ API key verification SUCCESSFUL"
        rm "$TEMP_FILE" 2>/dev/null
        return 0
    else
        echo "❌ API key verification FAILED with unexpected response:"
        cat "$TEMP_FILE"
        rm "$TEMP_FILE" 2>/dev/null
        return 1
    fi
}

# Function to show raw API response
raw_output() {
    if [ -z "$1" ]; then
        echo "Error: No search query provided."
        usage
        exit 1
    fi

    # Load API key from config file
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No API key configured. Run 'pplx configure' first."
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    if [ -z "$API_KEY" ]; then
        echo "Error: API key is empty. Run 'pplx configure' to set a valid key."
        exit 1
    fi

    # Create temporary file for the response
    TEMP_FILE=$(mktemp)
    QUERY="$1"

    echo "Sending query to Perplexity API: $QUERY"
    echo "Using model: $DEFAULT_MODEL"
    echo "Please wait..."
    
    # Properly escape the JSON string
    ESCAPED_QUERY=$(echo "$QUERY" | sed 's/"/\\"/g')
    
    # Create JSON payload with the specified model
    JSON_PAYLOAD=$(cat <<-END
{
  "model": "$DEFAULT_MODEL",
  "messages": [
    {
      "role": "system",
      "content": "Be accurate, helpful and concise."
    },
    {
      "role": "user",
      "content": "$ESCAPED_QUERY"
    }
  ]
}
END
)

    # Make API request with headers included
    echo "HTTP Request & Response (including headers):"
    echo "-------------------------------------------"
    curl -i -s -X POST "https://api.perplexity.ai/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$JSON_PAYLOAD"
    echo ""
    echo "-------------------------------------------"
}

# Function to perform the search
search() {
    MODEL="$DEFAULT_MODEL"
    
    # Check for model flag
    if [ "$1" = "-m" ]; then
        if [ -z "$2" ]; then
            echo "Error: No model specified after -m flag."
            usage
            exit 1
        fi
        MODEL="$2"
        shift 2
    fi
    
    if [ -z "$1" ]; then
        echo "Error: No search query provided."
        usage
        exit 1
    fi

    # Load API key from config file
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No API key configured. Run 'pplx configure' first."
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    if [ -z "$API_KEY" ]; then
        echo "Error: API key is empty. Run 'pplx configure' to set a valid key."
        exit 1
    fi

    # Create temporary file for the response
    TEMP_FILE=$(mktemp)
    QUERY="$1"

    echo "Searching Perplexity for: $QUERY"
    echo "Using model: $MODEL"
    echo "Please wait..."
    
    # Properly escape the JSON string
    ESCAPED_QUERY=$(echo "$QUERY" | sed 's/"/\\"/g')
    
    # Create JSON payload with the specified model
    JSON_PAYLOAD=$(cat <<-END
{
  "model": "$MODEL",
  "messages": [
    {
      "role": "system",
      "content": "Be accurate, helpful and concise."
    },
    {
      "role": "user",
      "content": "$ESCAPED_QUERY"
    }
  ]
}
END
)

    # Make API request - now with verbose output if DEBUG_MODE is on
    if [ "$DEBUG_MODE" = true ]; then
        echo "Sending request to API..."
        echo "Query: $ESCAPED_QUERY"
        echo "API Key (first 10 chars): ${API_KEY:0:10}..."
        echo "Using API endpoint: https://api.perplexity.ai/chat/completions"
        echo "Using model: $MODEL"
        echo "Request payload:"
        echo "$JSON_PAYLOAD"
        
        curl -v -X POST "https://api.perplexity.ai/chat/completions" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$JSON_PAYLOAD" > "$TEMP_FILE" 2>"${TEMP_FILE}.headers"
            
        echo "HTTP Headers from response:"
        cat "${TEMP_FILE}.headers"
        echo "Raw API Response:"
        cat "$TEMP_FILE"
    else
        curl -s -X POST "https://api.perplexity.ai/chat/completions" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$JSON_PAYLOAD" > "$TEMP_FILE"
    fi

    # Check if file is empty
    if [ ! -s "$TEMP_FILE" ]; then
        echo "Error: Empty response from API. Please check your internet connection."
        if [ "$DEBUG_MODE" = true ]; then
            rm "$TEMP_FILE" "${TEMP_FILE}.headers" 2>/dev/null
        else
            rm "$TEMP_FILE" 2>/dev/null
        fi
        exit 1
    fi

    # Check for 401 Authorization error
    if grep -q "401 Authorization Required" "$TEMP_FILE"; then
        echo "❌ ERROR: Authentication failed (401 Authorization Required)"
        echo ""
        echo "Your API key appears to be invalid or expired. Please run 'pplx configure' to update it."
        echo "Visit https://www.perplexity.ai/settings/api to manage your API keys"
        
        if [ "$DEBUG_MODE" = true ]; then
            rm "$TEMP_FILE" "${TEMP_FILE}.headers" 2>/dev/null
        else
            rm "$TEMP_FILE" 2>/dev/null
        fi
        exit 1
    fi

    # Check if response contains an error
    if grep -q "\"error\":" "$TEMP_FILE" || grep -q "\"message\":" "$TEMP_FILE" && ! grep -q "\"choices\":" "$TEMP_FILE"; then
        echo "Error from Perplexity API:"
        cat "$TEMP_FILE"
        
        if [ "$DEBUG_MODE" = true ]; then
            rm "$TEMP_FILE" "${TEMP_FILE}.headers" 2>/dev/null
        else
            rm "$TEMP_FILE" 2>/dev/null
        fi
        exit 1
    fi

    # Check if response is HTML instead of JSON
    if grep -q -i "<html" "$TEMP_FILE" || grep -q -i "<body" "$TEMP_FILE"; then
        echo "❌ ERROR: Received HTML response instead of JSON"
        echo ""
        echo "This usually means there was an authentication error or API endpoint issue."
        echo "Try running 'pplx verify' to check if your API key is valid."
        echo ""
        echo "Response preview:"
        head -n 5 "$TEMP_FILE"
        
        if [ "$DEBUG_MODE" = true ]; then
            rm "$TEMP_FILE" "${TEMP_FILE}.headers" 2>/dev/null
        else
            rm "$TEMP_FILE" 2>/dev/null
        fi
        exit 1
    fi

    # Display search results
    echo "----------------------------------------------"
    echo "SEARCH RESULTS:"
    echo "----------------------------------------------"
    
    # Try to use jq for JSON parsing, with fallback to simple extraction
    if command -v jq &> /dev/null; then
        # Attempt to validate JSON first
        if ! jq '.' "$TEMP_FILE" >/dev/null 2>&1; then
            echo "Warning: Invalid JSON response detected"
            echo "Raw response preview:"
            head -n 20 "$TEMP_FILE"
            echo "..."
            echo ""
            echo "Trying fallback extraction..."
            # Using grep to extract content between quotes after "content": 
            ANSWER=$(grep -o '"content":"[^"]*"' "$TEMP_FILE" | sed 's/"content":"//;s/"$//')
            echo "$ANSWER"
        else
            # JSON is valid, proceed with jq parsing
            jq -r '.choices[0].message.content' "$TEMP_FILE" 2>/dev/null || echo "Could not extract content from response"
            
            # Try to extract sources if they exist
            if jq -e '.choices[0].message.metadata.web_search_results' "$TEMP_FILE" >/dev/null 2>&1; then
                echo ""
                echo "SOURCES:"
                jq -r '.choices[0].message.metadata.web_search_results[] | "* " + .title + "\n  " + .url' "$TEMP_FILE" 2>/dev/null || echo "No formatted sources available"
            fi
        fi
    else
        # Basic parsing without jq
        echo "ANSWER:"
        # Try to extract content using grep and sed
        grep -o '"content":"[^"]*"' "$TEMP_FILE" | head -1 | sed 's/"content":"//;s/"$//' || echo "Unable to parse response."
        echo "Note: Install jq for better formatting and to see sources."
    fi
    
    echo "----------------------------------------------"
    
    # Clean up
    if [ "$DEBUG_MODE" = true ]; then
        rm "$TEMP_FILE" "${TEMP_FILE}.headers" 2>/dev/null
    else
        rm "$TEMP_FILE" 2>/dev/null
    fi
}

# Function to export search results to a file
export_results() {
    # Default values
    FORMAT="md"
    OUTPUT_FILE=""
    MODEL="$DEFAULT_MODEL"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--format)
                FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -m|--model)
                MODEL="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option $1"
                usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    # Check if a query was provided
    if [ -z "$1" ]; then
        echo "Error: No search query provided for export."
        usage
        exit 1
    fi
    
    # Validate format
    if [[ ! "$FORMAT" =~ ^(md|txt|pdf)$ ]]; then
        echo "Error: Invalid format '$FORMAT'. Use md, txt, or pdf."
        usage
        exit 1
    fi
    
    # Generate default output filename if none provided
    if [ -z "$OUTPUT_FILE" ]; then
        # Create a sanitized version of the query for the filename
        SANITIZED_QUERY=$(echo "$1" | tr -cs 'a-zA-Z0-9_-' '-' | head -c 30)
        TIMESTAMP=$(date +"%Y%m%d%H%M%S")
        OUTPUT_FILE="perplexity_${SANITIZED_QUERY}_${TIMESTAMP}.${FORMAT}"
    fi
    
    # If no extension, add it
    if [[ ! "$OUTPUT_FILE" =~ \.(md|txt|pdf)$ ]]; then
        OUTPUT_FILE="${OUTPUT_FILE}.${FORMAT}"
    fi
    
    # Create temporary files
    RESPONSE_FILE=$(mktemp)
    CONTENT_FILE=$(mktemp)
    
    echo "Searching Perplexity for: $1"
    echo "Using model: $MODEL"
    echo "Please wait..."
    
    # Load API key
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: No API key configured. Run 'pplx configure' first."
        rm "$RESPONSE_FILE" "$CONTENT_FILE" 2>/dev/null
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    if [ -z "$API_KEY" ]; then
        echo "Error: API key is empty. Run 'pplx configure' to set a valid key."
        rm "$RESPONSE_FILE" "$CONTENT_FILE" 2>/dev/null
        exit 1
    fi
    
    # Prepare the query
    QUERY="$1"
    ESCAPED_QUERY=$(echo "$QUERY" | sed 's/"/\\"/g')
    
    # Create JSON payload with the specified model
    JSON_PAYLOAD=$(cat <<-END
{
  "model": "$MODEL",
  "messages": [
    {
      "role": "system",
      "content": "Be accurate, helpful and concise."
    },
    {
      "role": "user",
      "content": "$ESCAPED_QUERY"
    }
  ]
}
END
)

    # Make API request
    curl -s -X POST "https://api.perplexity.ai/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$JSON_PAYLOAD" > "$RESPONSE_FILE"
    
    # Check for errors
    if [ ! -s "$RESPONSE_FILE" ]; then
        echo "Error: Empty response from API. Please check your internet connection."
        rm "$RESPONSE_FILE" "$CONTENT_FILE" 2>/dev/null
        exit 1
    fi
    
    if grep -q "401 Authorization Required" "$RESPONSE_FILE"; then
        echo "❌ ERROR: Authentication failed (401 Authorization Required)"
        echo "Your API key appears to be invalid or expired."
        rm "$RESPONSE_FILE" "$CONTENT_FILE" 2>/dev/null
        exit 1
    fi
    
    # Extract the content and sources
    if command -v jq &> /dev/null; then
        # Check if JSON is valid
        if ! jq '.' "$RESPONSE_FILE" >/dev/null 2>&1; then
            echo "Error: Invalid JSON response from API."
            rm "$RESPONSE_FILE" "$CONTENT_FILE" 2>/dev/null
            exit 1
        fi
        
        # Extract content
        ANSWER=$(jq -r '.choices[0].message.content // "No content found"' "$RESPONSE_FILE")
        
        # Create the document content based on format
        case "$FORMAT" in
            md)
                # Markdown format
                echo "# Perplexity Search Results" > "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Query" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$QUERY" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Answer" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$ANSWER" >> "$CONTENT_FILE"
                
                # Extract sources if available
                if jq -e '.choices[0].message.metadata.web_search_results' "$RESPONSE_FILE" >/dev/null 2>&1; then
                    echo "" >> "$CONTENT_FILE"
                    echo "## Sources" >> "$CONTENT_FILE"
                    echo "" >> "$CONTENT_FILE"
                    jq -r '.choices[0].message.metadata.web_search_results[] | "* [" + .title + "](" + .url + ")"' "$RESPONSE_FILE" >> "$CONTENT_FILE"
                fi
                
                echo "" >> "$CONTENT_FILE"
                echo "---" >> "$CONTENT_FILE"
                echo "Generated with Perplexity AI on $(date '+%Y-%m-%d at %H:%M:%S')" >> "$CONTENT_FILE"
                ;;
                
            txt)
                # Plain text format
                echo "PERPLEXITY SEARCH RESULTS" > "$CONTENT_FILE"
                echo "=========================" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "QUERY:" >> "$CONTENT_FILE"
                echo "$QUERY" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "ANSWER:" >> "$CONTENT_FILE"
                echo "$ANSWER" >> "$CONTENT_FILE"
                
                # Extract sources if available
                if jq -e '.choices[0].message.metadata.web_search_results' "$RESPONSE_FILE" >/dev/null 2>&1; then
                    echo "" >> "$CONTENT_FILE"
                    echo "SOURCES:" >> "$CONTENT_FILE"
                    jq -r '.choices[0].message.metadata.web_search_results[] | "* " + .title + "\n  " + .url' "$RESPONSE_FILE" >> "$CONTENT_FILE"
                fi
                
                echo "" >> "$CONTENT_FILE"
                echo "Generated with Perplexity AI on $(date '+%Y-%m-%d at %H:%M:%S')" >> "$CONTENT_FILE"
                ;;
                
            pdf)
                # Create markdown first, then convert to PDF
                echo "# Perplexity Search Results" > "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Query" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$QUERY" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Answer" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$ANSWER" >> "$CONTENT_FILE"
                
                # Extract sources if available
                if jq -e '.choices[0].message.metadata.web_search_results' "$RESPONSE_FILE" >/dev/null 2>&1; then
                    echo "" >> "$CONTENT_FILE"
                    echo "## Sources" >> "$CONTENT_FILE"
                    echo "" >> "$CONTENT_FILE"
                    jq -r '.choices[0].message.metadata.web_search_results[] | "* [" + .title + "](" + .url + ")"' "$RESPONSE_FILE" >> "$CONTENT_FILE"
                fi
                
                echo "" >> "$CONTENT_FILE"
                echo "---" >> "$CONTENT_FILE"
                echo "Generated with Perplexity AI on $(date '+%Y-%m-%d at %H:%M:%S')" >> "$CONTENT_FILE"
                ;;
        esac
    else
        # Fallback if jq is not available
        echo "Warning: jq is not installed. Export will have limited formatting."
        
        # Basic extraction
        ANSWER=$(grep -o '"content":"[^"]*"' "$RESPONSE_FILE" | head -1 | sed 's/"content":"//;s/"$//')
        
        case "$FORMAT" in
            md|pdf)
                echo "# Perplexity Search Results" > "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Query" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$QUERY" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "## Answer" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "$ANSWER" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "Note: Install jq for better formatting and to include sources." >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "Generated with Perplexity AI on $(date '+%Y-%m-%d at %H:%M:%S')" >> "$CONTENT_FILE"
                ;;
                
            txt)
                echo "PERPLEXITY SEARCH RESULTS" > "$CONTENT_FILE"
                echo "=========================" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "QUERY:" >> "$CONTENT_FILE"
                echo "$QUERY" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "ANSWER:" >> "$CONTENT_FILE"
                echo "$ANSWER" >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "Note: Install jq for better formatting and to include sources." >> "$CONTENT_FILE"
                echo "" >> "$CONTENT_FILE"
                echo "Generated with Perplexity AI on $(date '+%Y-%m-%d at %H:%M:%S')" >> "$CONTENT_FILE"
                ;;
        esac
    fi
    
    # Save to output file based on format
    case "$FORMAT" in
        md|txt)
            # Simply copy the file
            cp "$CONTENT_FILE" "$OUTPUT_FILE"
            ;;
            
        pdf)
            # Try different PDF conversion tools
            if command -v pandoc &> /dev/null; then
                echo "Converting to PDF using pandoc..."
                pandoc "$CONTENT_FILE" -o "$OUTPUT_FILE"
            elif command -v wkhtmltopdf &> /dev/null; then
                echo "Converting to PDF using wkhtmltopdf..."
                # Create a temporary HTML file
                HTML_FILE=$(mktemp --suffix=.html)
                # Convert markdown to HTML first - using a simple approach
                echo "<html><body style='font-family: Arial, sans-serif; max-width: 800px; margin: 20px auto;'>" > "$HTML_FILE"
                # Basic markdown conversion
                cat "$CONTENT_FILE" | sed -e 's/^# \(.*\)/<h1>\1<\/h1>/g' \
                                         -e 's/^## \(.*\)/<h2>\1<\/h2>/g' \
                                         -e 's/^\* \(.*\)/<li>\1<\/li>/g' \
                                         -e 's/^$/<p><\/p>/g' \
                                         >> "$HTML_FILE"
                echo "</body></html>" >> "$HTML_FILE"
                # Convert HTML to PDF
                wkhtmltopdf "$HTML_FILE" "$OUTPUT_FILE"
                rm -f "$HTML_FILE"
            elif command -v enscript &> /dev/null && command -v ps2pdf &> /dev/null; then
                echo "Converting to PDF using enscript and ps2pdf..."
                PS_FILE=$(mktemp --suffix=.ps)
                enscript -p "$PS_FILE" "$CONTENT_FILE"
                ps2pdf "$PS_FILE" "$OUTPUT_FILE"
                rm -f "$PS_FILE"
            else
                echo "Error: Cannot convert to PDF. Please install pandoc, wkhtmltopdf, or enscript+ps2pdf."
                cp "$CONTENT_FILE" "${OUTPUT_FILE%.pdf}.txt"
                echo "Saved as plain text file instead: ${OUTPUT_FILE%.pdf}.txt"
                OUTPUT_FILE="${OUTPUT_FILE%.pdf}.txt"
            fi
            ;;
    esac
    
    # Clean up temporary files
    rm -f "$RESPONSE_FILE" "$CONTENT_FILE"
    
    echo "✅ Results exported to: $OUTPUT_FILE"
}

# Main command router
case "$1" in
    search)
        shift
        search "$@"
        ;;
    debug)
        shift
        DEBUG_MODE=true
        search "$@"
        ;;
    raw)
        shift
        raw_output "$*"
        ;;
    export)
        shift
        export_results "$@"
        ;;
    configure)
        configure
        ;;
    verify)
        verify_api_key
        ;;
    models)
        list_models
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

exit 0