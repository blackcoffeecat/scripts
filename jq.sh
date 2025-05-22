#!/bin/bash
# jq - A simplified jq-like tool implemented in bash for basic JSON parsing
# Usage: curl -s https://blackcoffeecat.github.io/scripts/jq.sh | bash -s -- [options] <query> [JSON string]

# Parse command line arguments
raw_output=false
compact_output=false
query=""
json_input=""

# Display help information
show_help() {
  cat << EOF
jq - A simplified jq-like tool implemented in bash for basic JSON parsing

Usage: 
  curl -s https://your-cdn-url/jq.sh | bash -s -- [options] <query> '[JSON string]'
  or
  curl -s https://your-cdn-url/jq.sh > jq.sh && chmod +x jq.sh
  ./jq.sh [options] <query> '[JSON string]'

Options:
  -h, --help     Display this help information
  -r, --raw      Output raw strings (without quotes)
  -c, --compact  Output compact JSON (no formatting)

Query syntax:
  .              Output the entire JSON document
  .key          Get the value of a key in an object
  .key1.key2    Get nested values in objects
  .[0]          Get the first element of an array
  .[1:3]        Get elements 1-2 from an array (zero-based indexing)
  .[]           Expand all elements in an array

Examples:
  curl -s https://your-cdn-url/jq.sh | bash -s -- . '{"name":"John"}'
  curl -s https://your-cdn-url/jq.sh | bash -s -- .name '{"name":"John"}'
  echo '{"name":"John"}' | curl -s https://your-cdn-url/jq.sh | bash -s -- .name
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    -r|--raw)
      raw_output=true
      shift
      ;;
    -c|--compact)
      compact_output=true
      shift
      ;;
    -*)
      echo "Error: Unknown option $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$query" ]]; then
        query="$1"
      elif [[ -z "$json_input" ]]; then
        json_input="$1"
      else
        echo "Error: Too many arguments" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# If no query is provided, show help
if [[ -z "$query" ]]; then
  show_help
fi

# If no JSON input is provided, try to read from stdin
if [[ -z "$json_input" ]]; then
  # Check if there's stdin input
  if [ -t 0 ]; then
    echo "Error: No JSON input provided" >&2
    exit 1
  fi
  json_input=$(cat)
fi

# Function to process JSON
process_json() {
  local json="$1"
  local q="$query"
  
  # Process entire document
  if [[ "$q" == "." ]]; then
    if [[ "$compact_output" == true ]]; then
      echo "$json" | tr -d '\n\t ' | sed 's/}/}\n/g' | sed 's/,/,\n/g'
    else
      # Use Python for formatting if available
      if command -v python3 &>/dev/null; then
        echo "$json" | python3 -m json.tool
      elif command -v python &>/dev/null; then
        echo "$json" | python -m json.tool
      else
        # Simple formatting without Python dependency
        echo "$json" | sed 's/,/,\n/g' | sed 's/{/{\n/g' | sed 's/}/\n}/g' | sed 's/\[/\[\n/g' | sed 's/\]/\n\]/g' | sed 's/:/: /g' | sed 's/^ */  &/g'
      fi
    fi
    return
  fi
  
  # Process field queries
  if [[ "$q" =~ ^\.[a-zA-Z0-9_]+ ]]; then
    # Extract field name (remove leading dot)
    local field="${q:1}"
    
    # Handle nested fields
    if [[ "$field" == *"."* ]]; then
      local parts=(${field//./ })
      local result="$json"
      
      for part in "${parts[@]}"; do
        # Handle array indices
        if [[ "$part" =~ \[[0-9]+\]$ ]]; then
          local key="${part%\[*}"
          local index="${part#*\[}"
          index="${index%\]}"
          
          if [[ -n "$key" ]]; then
            # First get the key, then the array index
            result=$(echo "$result" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\[[^]]*\]" | sed 's/.*\[\([^]]*\)\].*/\1/' | tr ',' '\n' | sed -n "$((index+1))p" | tr -d ' \t\n')
          else
            # Directly get array index
            result=$(echo "$result" | tr ',' '\n' | sed -n "$((index+1))p" | tr -d ' \t\n')
          fi
        else
          # Regular field
          result=$(echo "$result" | grep -o "\"$part\"[[:space:]]*:[[:space:]]*[^,}]*" | sed "s/\"$part\"[[:space:]]*:[[:space:]]*//")
        fi
      done
      
      # Output result
      if [[ "$raw_output" == true ]]; then
        echo "$result" | tr -d '"'
      else
        echo "$result"
      fi
      return
    fi
    
    # Handle simple fields
    local value=$(echo "$json" | grep -o "\"$field\"[[:space:]]*:[[:space:]]*[^,}]*" | sed "s/\"$field\"[[:space:]]*:[[:space:]]*//")
    
    # Output result
    if [[ "$raw_output" == true ]]; then
      echo "$value" | tr -d '"'
    else
      echo "$value"
    fi
    return
  fi
  
  # Handle array indices
  if [[ "$q" =~ ^\.\[[0-9]+\]$ ]]; then
    local index="${q#.\[}"
    index="${index%\]}"
    
    # Extract array
    local array=$(echo "$json" | sed 's/.*\[\([^]]*\)\].*/\1/')
    
    # Get element at specified index
    local value=$(echo "$array" | tr ',' '\n' | sed -n "$((index+1))p" | tr -d ' \t\n')
    
    # Output result
    if [[ "$raw_output" == true ]]; then
      echo "$value" | tr -d '"'
    else
      echo "$value"
    fi
    return
  fi
  
  # Handle array slices
  if [[ "$q" =~ ^\.\[[0-9]+:[0-9]+\]$ ]]; then
    local range="${q#.\[}"
    range="${range%\]}"
    local start="${range%:*}"
    local end="${range#*:}"
    
    # Extract array
    local array=$(echo "$json" | sed 's/.*\[\([^]]*\)\].*/\1/')
    
    # Get elements in specified range
    local result="["
    local i=0
    IFS=',' read -ra elements <<< "$array"
    for element in "${elements[@]}"; do
      if [[ $i -ge $start && $i -lt $end ]]; then
        if [[ "$result" != "[" ]]; then
          result+=","
        fi
        result+="$element"
      fi
      ((i++))
    done
    result+="]"
    
    # Output result
    echo "$result"
    return
  fi
  
  # Handle array expansion
  if [[ "$q" == ".[]" ]]; then
    # Extract array
    local array=$(echo "$json" | sed 's/.*\[\([^]]*\)\].*/\1/')
    
    # Expand array elements
    IFS=',' read -ra elements <<< "$array"
    for element in "${elements[@]}"; do
      if [[ "$raw_output" == true ]]; then
        echo "$element" | tr -d '"' | tr -d ' \t\n'
      else
        echo "$element" | tr -d ' \t\n'
      fi
    done
    return
  fi
  
  # Unknown query
  echo "Error: Unsupported query syntax '$q'" >&2
  exit 1
}

# Main processing logic
process_json "$json_input"
