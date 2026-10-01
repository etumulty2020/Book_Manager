#!/bin/bash
# Book component: list the books in the user's library.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

# No argument at all lists every book; an empty status is an error (from the data layer)
if [[ $# -eq 0 ]]; then
    list_books
else
    list_books_by_status "$1"
fi
