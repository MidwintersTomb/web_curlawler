#!/bin/bash

MAX_JOBS=500
MAX_DEPTH=3

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

while getopts ":u:w:e:o:d:" opt; do
    case ${opt} in
        u) base_url=$OPTARG ;;
        w) wordlist=$OPTARG ;;
        e) extensions=$OPTARG ;;
        o) output_file=$OPTARG ;;
        d) MAX_DEPTH=$OPTARG ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument"
            exit 1
            ;;
    esac
done

if [[ -z "$base_url" || -z "$wordlist" || -z "$extensions" ]]; then
    echo "Usage:"
    echo "$0 -u https://target.tld -w wordlist.txt -e php,txt,html [-o output.txt] [-d depth]"
    exit 1
fi

IFS=',' read -ra EXTENSIONS <<< "$extensions"

print_result() {
    local url="$1"
    local code="$2"

    local color="$NC"

    case "$code" in
        2*)
            color="$GREEN"
            ;;
        3*)
            color="$BLUE"
            ;;
        401|403)
            color="$YELLOW"
            ;;
        *)
            color="$RED"
            ;;
    esac

    printf "%s [%b%s%b]\n" "$url" "$color" "$code" "$NC"

    if [[ -n "$output_file" ]]; then
        printf "%s [%s]\n" "$url" "$code" >> "$output_file"
    fi
}

check_url() {
    local url="$1"

    local code

    code=$(curl -sL --connect-timeout 3 --max-time 10 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0" -o /dev/null -w "%{http_code}" "$url")

    if [[ "$code" =~ ^(200|204|301|302|307|308|401|403)$ ]]; then
        print_result "$url" "$code"
        return 0
    fi

    return 1
}

declare -A VISITED

QUEUE_URLS=()
QUEUE_DEPTHS=()

enqueue() {
    local url="$1"
    local depth="$2"

    if [[ -n "${VISITED[$url]}" ]]; then
        return
    fi

    VISITED["$url"]=1

    QUEUE_URLS+=("$url")
    QUEUE_DEPTHS+=("$depth")
}

dequeue() {
    CURRENT_URL="${QUEUE_URLS[0]}"
    CURRENT_DEPTH="${QUEUE_DEPTHS[0]}"

    QUEUE_URLS=("${QUEUE_URLS[@]:1}")
    QUEUE_DEPTHS=("${QUEUE_DEPTHS[@]:1}")
}

enumerate_directory() {
    local base="$1"
    local depth="$2"

    while IFS= read -r word || [[ -n "$word" ]]; do

        [[ -z "$word" ]] && continue
        [[ "$word" =~ ^# ]] && continue

        local url="$base/$word"

        while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
            sleep 0.05
        done

        (
            if check_url "$url"; then
                if (( depth < MAX_DEPTH )); then
                    echo "$url" >> "$TMP_QUEUE"
                fi
            fi
        ) &

        for ext in "${EXTENSIONS[@]}"; do

            while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do
                sleep 0.05
            done

            (
                check_url "$url.$ext"
            ) &
        done

    done < "$wordlist"

    wait
}

TMP_QUEUE=$(mktemp)

trap 'rm -f "$TMP_QUEUE"' EXIT

enqueue "$base_url" 0

echo "Starting crawl..."
echo

while (( ${#QUEUE_URLS[@]} > 0 )); do

    dequeue

    echo "[Depth $CURRENT_DEPTH] Crawling $CURRENT_URL"

    > "$TMP_QUEUE"

    enumerate_directory "$CURRENT_URL" "$CURRENT_DEPTH"

    if (( CURRENT_DEPTH < MAX_DEPTH )); then

        while IFS= read -r discovered; do

            [[ -z "$discovered" ]] && continue

            enqueue "$discovered" $((CURRENT_DEPTH + 1))

        done < "$TMP_QUEUE"

    fi
done

echo
echo "Crawl complete."
