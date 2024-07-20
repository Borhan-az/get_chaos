#!/bin/bash

# Function to display a progress bar
  progress_bar() {
  local current=$1
  local total=$2
  local percent=$(( (current * 100) / total ))
  local bar_length= 50
  local filled_length=$(( (bar_length * percent) / 100 ))
  local empty_length=$(( bar_length - filled_length ))

  local bar=$(printf "%-${bar_length}s" "#" | head -c $filled_length)
  local empty=$(printf "%-${bar_length}s" " " | head -c $empty_length)

  printf "\rProgress: [${bar}${empty}] ${percent}%%"
}

usage() {
  cat <<EOF

Usage: get_chaos [OPTIONS]

Options:
  --platform=<platform>     Platforms: hackerone, bugcrowd, intigriti, yeswehack
  --bounty=<bounty>         Has bounty: true/false
  --update=<date>           Date greater than: "2024-02"
  -h, --help                help

EOF
}   
get_chaos() {
  local json_input="$1"
  local platform_filter="${2:-}"
  local bounty_filter="${3:-}"
  local last_updated_filter="${4:-}"

  urls=($(jq -r --arg platform "$platform_filter" --arg bounty "$bounty_filter" --arg last_updated "$last_updated_filter" '
    .[] | select(
      ($platform == "" or .platform == $platform) and 
      ($bounty == "" or .bounty == $bounty) and 
      ($last_updated == "" or .last_updated > $last_updated)
    ) | .URL
  ' <<< "$json_input"))

  total=${#urls[@]}
  count=0     

  for url in "${urls[@]}"; do
    wget -q $url -O temp.zip
    ((count++))
    progress_bar $count $total

    unzip -q temp.zip
    rm temp.zip
  done
  echo # To ensure the progress bar line is terminated

  platform=$(echo "$platform_filter" | sed 's/^"\(.*\)"$/\1/')

  if [[ -n "$platform" && ! -d "$platform" ]]; then
    mkdir -p "$platform"
  fi
  if [[ -n "$platform" ]]; then
    mv *.txt "$platform/"
    cd "$platform" || exit
  fi
}

# Default filters
platform_filter=""
bounty_filter=""
last_updated_filter=""

while [[ "$#" -gt 0 ]]; do
  case $1 in
    --platform=*) platform_filter="${1#*=}" ;;
    --bounty=*) bounty_filter="${1#*=}" ;;
    --update=*) last_updated_filter="${1#*=}" ;;
    --help|-h   ) usage ; exit 0 ;;
    *) echo "Unknown parameter : $1"; exit 1 ;;
  esac
  shift
done

json_data=$(curl -s https://chaos-data.projectdiscovery.io/index.json)

get_chaos "$json_data" "$platform_filter" "$bounty_filter" "$last_updated_filter"

