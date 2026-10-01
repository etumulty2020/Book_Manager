#!/bin/bash
# Book component: look up one book in the user's library.
# Prints the book's full row (title,author,genre,status,rating,link).
# Exits with 1 if the book isn't in the library, so it also answers "do I have this book?"

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

get_book "$1"
