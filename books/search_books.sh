#!/bin/bash
# Book component: search the user's library.

# Prints "Title by Author" for each book whose title or author contains the term.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

# Term from the first argument, or from a pipe
term="$1"
if [[ -z "$term" && ! -t 0 ]]; then
    read -r term
fi

search_books "$term"
