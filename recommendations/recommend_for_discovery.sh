#!/bin/bash
# Recommendation agent: deliberately explore beyond the user's normal patterns.
#
# Picks 3 random subjects not in the library's genres and finds Open Library books in
# them by authors the user hasn't read.
# Output (stdout): books.csv-style rows, then "#elapsed,SECONDS". Messages go to stderr.
# Duplicates and polishing are left to refine_recommendations.sh.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

# Timer: on exit, print "#elapsed,SECONDS" for refine_recommendations.sh to show
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
start="$(now)"
trap 'awk -v a="$start" -v b="$(now)" '\''BEGIN { printf "#elapsed,%.2f\n", b - a }'\''' EXIT

num_subjects=3      # how many new subjects to explore
per_subject=3       # how many books to print for each subject

# Subjects to explore, as Open Library subject names
subjects="poetry graphic_novels philosophy psychology economics art_history music
travel cooking mythology biography true_crime humor short_stories plays
astronomy mathematics medicine religion sports architecture linguistics
magical_realism westerns cyberpunk"

# Genres already in the library, lowercased for comparison
known_genres="$(list_genres | tr '[:upper:]' '[:lower:]')"

# Drop subjects that appear in a library genre (e.g. "science"), then pick some at random
new_subjects="$(for s in $subjects; do
    grep -Fqi -- "${s//_/ }" <<< "$known_genres" || echo "$s"
done | awk 'BEGIN { srand() } { print rand() "\t" $0 }' | sort -n | cut -f2 | head -n "$num_subjects")"

while read -r subject; do
    genre="${subject//_/ }"
    echo "discovery agent: exploring $genre..." >&2

    # Ask for 20 results, since some will be by authors the user already has
    curl -s -m 10 -G "https://openlibrary.org/search.json" \
        --data-urlencode "subject=$genre" -d "fields=title,author_name" -d "limit=20" |
    jq -r '.docs[]? | [.title, (.author_name[0] // "Unknown")] | @tsv' |
    # Skip authors already in the library (list_authors is read first)
    awk -F'\t' 'FNR == NR { known[tolower($0)]; next } !(tolower($2) in known)' <(list_authors) - |
    # Make a books.csv row: drop commas; rating and link stay empty (refine adds links)
    awk -F'\t' -v OFS=',' -v genre="$genre" '{ gsub(/,/, "", $1); gsub(/,/, "", $2)
        print $1, $2, genre, "want_to_read", "", "" }' | head -n "$per_subject"
done <<< "$new_subjects"
