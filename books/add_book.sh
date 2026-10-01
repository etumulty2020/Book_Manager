#!/bin/bash
# Book component: save a new book to the user's library.
# New books start as want_to_read with no rating.
# Exits with 1 if a book with that title is already in the library.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

add_book "$1" "$2" "$3" want_to_read ""
