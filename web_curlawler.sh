#!/bin/bash

while getopts ":u:w:e:" opt; do
  case ${opt} in
    u )
      base_url=$OPTARG
      ;;
    w )
      wordlist=$OPTARG
      ;;
    e )
      extensions=$OPTARG
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ -z "$base_url" ] || [ -z "$wordlist" ] || [ -z "$extensions" ]; then
  echo "Usage: $0 -u https://domain.tld -w /path/to/wordlist.txt -e list,of,extensions" 1>&2
  exit 1
fi

check_url() {
  local url="$1"
  local response_code=$(curl -sL -w "%{http_code}\\n" -o /dev/null -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0" "$url")
  if [ "$response_code" -eq 200 ]; then
    echo "$url"
    search_directories "$url" "$wordlist" "$extensions"
  fi
}

search_directories() {
  local base="$1"
  local wordlist="$2"
  local extensions="$3"

  while IFS= read -r word || [[ -n "$word" ]]; do
    if [[ "${word:0:1}" == "#" ]]; then 
      continue
    elif [ -z "$word" ]; then
      continue
    fi

    local url="$base/$word"
    check_url "$url"

    for ext in $(echo "$extensions" | tr ',' '\n'); do
      local url_with_ext="$url.$ext"
      check_url "$url_with_ext"
    done
  done < "$wordlist"
}

crawl_url() {
  local url="$1"
  local wordlist="$2"
  local extensions="$3"

  search_directories "$url" "$wordlist" "$extensions"

  while read -r dir; do
    search_directories "$url/$dir" "$wordlist" "$extensions"
  done < <(curl -s "$url" | grep -oP '(?<=href=")[^"]+(?=/")' | grep '/$' | sed 's#/$##')
}

echo "$base_url"

crawl_url "$base_url" "$wordlist" "$extensions"
