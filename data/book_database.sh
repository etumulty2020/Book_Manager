#!/bin/bash
# Data abstraction layer.
# The only file that reads or writes books.csv.

# books.csv sits next to this file, so this path works from any directory
BOOKS_CSV="$(dirname "${BASH_SOURCE[0]}")/books.csv"

# add_book TITLE AUTHOR GENRE STATUS RATING [SERIES]
# SERIES defaults to "-" (not part of a series)
add_book() {
    local title="$1" author="$2" genre="$3" book_status="$4" rating="$5" series="${6:--}"
    local link="https://www.google.com/search?tbm=bks&q=${title// /%20}%20${author// /%20}"

    # Refuse a title that's already in the library (ignoring case)
    if awk -F',' -v t="$title" 'NR > 1 && tolower($1) == tolower(t) { found = 1; exit }
        END { exit !found }' "$BOOKS_CSV"; then
        echo "This book already exists"
        return 1
    fi

    # Make sure the new row starts on its own line
    [[ -n "$(tail -c 1 "$BOOKS_CSV")" ]] && echo >> "$BOOKS_CSV"

    echo "$title,$author,$genre,$book_status,$rating,$link,$series" >> "$BOOKS_CSV"
}

# list_books
# Prints title,author,status,rating,series for every book in books.csv
list_books() {
    # NR > 1 skips the header row
    awk -F',' -v OFS=',' 'NR > 1 { print $1, $2, $4, $5, $7 }' "$BOOKS_CSV"
}

# list_books_by_status STATUS
# Prints the title and author of every book whose status matches STATUS (case-insensitive)
list_books_by_status() {
    local book_status="$1"

    if [[ -z "$book_status" ]]; then
        echo "Error: status is required (finished, reading, want_to_read, or owned)" >&2
        return 1
    fi

    # $4 is the status column; NR > 1 skips the header
    awk -F',' -v s="$book_status" 'NR > 1 && tolower($4) == tolower(s) { print $1 " by " $2 }' "$BOOKS_CSV"
}

# get_books_by_status STATUS
# Prints the full row of every book whose status matches STATUS (case-insensitive)
get_books_by_status() {
    local book_status="$1"

    awk -F',' -v s="$book_status" 'NR > 1 && tolower($4) == tolower(s) { print }' "$BOOKS_CSV"
}

# list_titles
# Prints the title of every book in books.csv, one per line
list_titles() {
    awk -F',' 'NR > 1 { print $1 }' "$BOOKS_CSV"
}

# list_genres
# Prints each genre in books.csv once
list_genres() {
    awk -F',' 'NR > 1 && !seen[$3]++ { print $3 }' "$BOOKS_CSV"
}

# list_authors
# Prints each author in books.csv once
list_authors() {
    awk -F',' 'NR > 1 && !seen[$2]++ { print $2 }' "$BOOKS_CSV"
}

# search_books TERM
# Prints "Title by Author" for books whose title or author contains TERM
# (case-insensitive; spaces around TERM are ignored).
search_books() {
    awk -F',' -v term="$1" 'BEGIN { gsub(/^[ \t]+|[ \t]+$/, "", term); term = tolower(term) }
        NR > 1 && (index(tolower($1), term) || index(tolower($2), term)) { print $1 " by " $2 }' "$BOOKS_CSV"
}

# update_book TITLE STATUS RATING
# Changes the status and/or rating of the book with this title.
# Pass "" to leave a field unchanged.
update_book() {
    local title="$1" new_status="$2" new_rating="$3"

    # Only the four statuses the library uses
    case "$new_status" in
        ""|finished|reading|want_to_read|owned) ;;
        *) echo "Error: status must be finished, reading, want_to_read, or owned" >&2; return 1 ;;
    esac

    # Rating must be a whole number (or empty to skip)
    if [[ -n "$new_rating" && ! "$new_rating" =~ ^[0-9]+$ ]]; then
        echo "Error: rating must be a number" >&2
        return 1
    fi

    # Write the updated file to a temp file, then replace the original
    local tmp
    tmp="$(mktemp)"
    awk -F',' -v OFS=',' -v t="$title" -v s="$new_status" -v r="$new_rating" '
        NR > 1 && tolower($1) == tolower(t) {
            if (s != "") $4 = s     # status column
            if (r != "") $5 = r     # rating column
            found = 1
        }
        { print }
        END { exit !found }' "$BOOKS_CSV" > "$tmp"

    if [[ $? -eq 0 ]]; then
        mv "$tmp" "$BOOKS_CSV"
    else
        rm "$tmp"
        echo "Error: '$title' not found" >&2
        return 1
    fi
}

# rate_book TITLE RATING
# Saves a 1-5 rating for this title (case-insensitive).
# Returns 1 if the rating isn't 1-5 or the book isn't found.
rate_book() {
    if [[ ! "$2" =~ ^[1-5]$ ]]; then
        echo "Error: rating must be a whole number from 1 to 5" >&2
        return 1
    fi
    update_book "$1" "" "$2"
}

# set_status TITLE STATUS
# Saves a new status for this title (case-insensitive).
# Returns 1 if the status isn't allowed or the book isn't found.
set_status() {
    if [[ -z "$2" ]]; then
        echo "Error: status must be finished, reading, want_to_read, or owned" >&2
        return 1
    fi
    update_book "$1" "$2" ""
}

# get_book TITLE
# Prints the full CSV row for the book with this exact title (case-insensitive).
# Returns 1 if the book isn't found.
get_book() {
    local title="$1"

    awk -F',' -v t="$title" 'NR > 1 && tolower($1) == tolower(t) { print; found = 1; exit }
        END { exit !found }' "$BOOKS_CSV"
}
