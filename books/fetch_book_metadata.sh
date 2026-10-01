#!/bin/bash
# Book component: enrich basic book information with metadata.
#
# Input:  a title and an author
# Output: title,author,genre   e.g.  Dune,Frank Herbert,Science Fiction
#
# Looks the book up on Open Library and picks its genre from the book's subjects,
# preferring genres already in the library. Falls back to "Unknown".

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

# Commas would break the CSV columns, so drop them
title="${1//,/}"
author="${2//,/}"

if [[ -z "$title" ]]; then
    echo "Usage: fetch_book_metadata.sh TITLE AUTHOR" >&2
    exit 1
fi

# Common genres, used when no library genre matches
common_genres="Fantasy,Science Fiction,Romance,Mystery,Thriller,Horror,Historical Fiction,\
Literary Fiction,Young Adult,Children's Literature,Poetry,Drama,Graphic Novels,Biography,\
Autobiography,Memoir,History,Science,Philosophy,Psychology,Religion,Politics,Economics,\
Business,Self-Help,Travel,Humor,Cooking,Art,Music,Technology"

# Get the book's subjects, one per line, from the first of 5 matches that has any
lookup_subjects() {
    curl -s -m 15 -G "https://openlibrary.org/search.json" \
        --data-urlencode "title=$title" --data-urlencode "author=$author" \
        -d "fields=subject" -d "limit=5" |
    jq -r 'first(.docs[] | select(.subject)) | .subject[]' 2>/dev/null
}

# Open Library sometimes drops requests, so retry once
subjects="$(lookup_subjects)"
if [[ -z "$subjects" ]]; then
    sleep 1
    subjects="$(lookup_subjects)"
fi

if [[ -z "$subjects" ]]; then
    echo "fetch: no details found on Open Library for $title" >&2
    echo "$title,$author,Unknown"
    exit 0
fi

# Non-fiction genres rank last for fiction books, so a historical novel gets
# "Historical Fiction" rather than "History".
nonfiction_genres="biography,autobiography,memoir,history,science,philosophy,psychology,\
religion,politics,economics,business,self help,travel,cooking,art,music,technology,\
design,environmental science"

# Pick the best-ranked genre among the subjects (lower wins; ties go to the first):
#   1 = library genre, 2 = common genre, +2 for a non-fiction genre on a fiction book
# Subjects like "Fiction, Romance, Historical" are split so "Romance" can match.
genre="$(awk -v nonfiction="$nonfiction_genres" '
    BEGIN {
        n = split(nonfiction, words, ",")
        for (i = 1; i <= n; i++) is_nonfiction[words[i]] = 1
    }

    # First input: known genres as "rank<TAB>genre" (library genres are rank 1)
    FNR == NR {
        split($0, f, "\t"); k = tolower(f[2]); gsub(/-/, " ", k)
        if (!(k in known)) { known[k] = f[2]; rank[k] = f[1] }
        next
    }

    # Second input: the book subjects. Remember each known genre, in order.
    {
        n = split($0, parts, /, | \/ /)
        for (i = 1; i <= n; i++) {
            p = tolower(parts[i]); gsub(/-/, " ", p)    # "Science-fiction" -> "science fiction"
            if (p == "fiction") is_fiction = 1
            if ((p in known) && !(p in seen)) { seen[p] = 1; matches[++m] = p }
        }
    }

    END {
        for (i = 1; i <= m; i++) {
            p = matches[i]
            r = rank[p]
            if (is_fiction && (p in is_nonfiction)) r += 2
            if (best == "" || r < best_rank) { best = p; best_rank = r }
        }
        # No known genre: fall back to plain Fiction, or Unknown
        if (best != "") print known[best]
        else print (is_fiction ? "Fiction" : "Unknown")
    }
' <(list_genres | sed 's/^/1	/'; tr ',' '\n' <<< "$common_genres" | sed 's/^/2	/') - <<< "$subjects")"

echo "$title,$author,$genre"
