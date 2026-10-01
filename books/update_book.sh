#!/bin/bash
# Book component: change a book's rating or status.
# Exits with 1 (and an error on stderr) if the value isn't allowed or the book isn't found.

source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

case "$1" in
    rating) rate_book "$2" "$3" ;;
    status) set_status "$2" "$3" ;;
    *)
        echo "Usage: update_book.sh rating TITLE 1-5 | status TITLE STATUS" >&2
        exit 1 ;;
esac
