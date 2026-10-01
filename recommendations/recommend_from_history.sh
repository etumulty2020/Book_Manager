#!/bin/bash
# Recommendation agent: recommend from reading history and saved books.
#
# Scores genres from the user's finished, reading and owned books and their ratings,
# then finds 3 popular Open Library books in each of the top 3 genres.
# Output (stdout): books.csv-style rows, then "#elapsed,SECONDS". Messages go to stderr.
# Duplicates and books already in the library are left to refine_recommendations.sh.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

# Timer: on exit, print "#elapsed,SECONDS" for refine_recommendations.sh to show
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
start="$(now)"
trap 'awk -v a="$start" -v b="$(now)" '\''BEGIN { printf "#elapsed,%.2f\n", b - a }'\''' EXIT

top_genres=3        # how many favourite genres to search
per_genre=3         # how many books to fetch for each genre

# Status weights: finished 3, reading 2, owned 1 (completed / in_progress / saved are
# accepted too). want_to_read books are left out: the user hasn't shown interest yet.
interested_statuses="finished:3 completed:3 reading:2 in_progress:2 owned:1 saved:1"

# 1. Collect those books, with the status weight added as a first column
history=""
for entry in $interested_statuses; do
    book_status="${entry%%:*}"
    weight="${entry##*:}"
    history+="$(get_books_by_status "$book_status" | awk -v w="$weight" '{ print w "," $0 }')"$'\n'
done

if [[ -z "${history//$'\n'/}" ]]; then
    echo "history agent: no reading history yet, nothing to recommend" >&2
    exit 0
fi

# 2. Score genres: each book adds status weight x stars (1-5; unrated = 0.5, so it
#    counts less than any rated book). Columns: weight,title,author,genre,status,rating
#    Output: the top genres, highest score first
genres="$(awk -F',' 'NF {
        stars = ($6 ~ /^[1-5]$/) ? $6 : 0.5
        score[$4] += $1 * stars
    }
    END { for (g in score) print score[g] "," g }' <<< "$history" |
    sort -t',' -k1,1nr -k2,2 | head -n "$top_genres" | cut -d',' -f2)"

# 3. For each favourite genre, fetch popular books from Open Library
while read -r genre; do
    # Open Library subjects look like "science_fiction"
    subject="$(echo "$genre" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"
    echo "history agent: searching Open Library for $genre books..." >&2

    curl -s -m 10 "https://openlibrary.org/subjects/${subject}.json?limit=$per_genre" |
    jq -r '.works[]? | [.title, (.authors[0].name // "Unknown")] | @tsv' |
    # Make a books.csv row: drop commas; rating and link stay empty (refine adds links)
    awk -F'\t' -v OFS=',' -v genre="$genre" '{ gsub(/,/, "", $1); gsub(/,/, "", $2)
        print $1, $2, genre, "want_to_read", "", "" }'
done <<< "$genres"
