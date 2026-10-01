#!/bin/bash
# Recommendation agent: recommend from the user's interests and goals.

# Finds 3 Open Library books for each interest.
# Output (stdout): books.csv-style rows, then "#elapsed,SECONDS". Messages go to stderr.
# Duplicates and books already in the library are left to refine_recommendations.sh.

# Timer: on exit, print "#elapsed,SECONDS" for refine_recommendations.sh to show
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
start="$(now)"
trap 'awk -v a="$start" -v b="$(now)" '\''BEGIN { printf "#elapsed,%.2f\n", b - a }'\''' EXIT

per_topic=3

# Interests from the first argument, or ask for them
interests="$1"
if [[ -z "$interests" ]]; then
    read -r -p "Enter interests, topics, or fields (comma-separated): " interests
fi

IFS=',' read -ra topics <<< "$interests"
if [[ ${#topics[@]} -eq 0 ]]; then
    echo "interests agent: no interests given" >&2
    exit 1
fi

for topic in "${topics[@]}"; do
    topic="$(echo "$topic" | xargs)"    # trim spaces
    [[ -z "$topic" ]] && continue
    echo "interests agent: searching Open Library for $topic books..." >&2

    curl -s -m 10 -G "https://openlibrary.org/search.json" \
        --data-urlencode "subject=$topic" -d "fields=title,author_name" -d "limit=$per_topic" |
    jq -r '.docs[]? | [.title, (.author_name[0] // "Unknown")] | @tsv' |
    # Make a books.csv row: drop commas; rating and link stay empty (refine adds links)
    awk -F'\t' -v OFS=',' -v genre="$topic" '{ gsub(/,/, "", $1); gsub(/,/, "", $2)
        print $1, $2, genre, "want_to_read", "", "" }'
done
