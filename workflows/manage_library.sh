#!/bin/bash
# Workflow layer: coordinate library operations.
# Every action goes through a book component; this file never calls the data layer.
BOOKS="$(dirname "${BASH_SOURCE[0]}")/../books"

case "$1" in
    list)    bash "$BOOKS/list_books.sh" ;;
    search)  bash "$BOOKS/search_books.sh" "$2" ;;
    status)  bash "$BOOKS/list_books.sh" "$2" ;;
    details) bash "$BOOKS/book_details.sh" "$2" ;;
    rate)
        bash "$BOOKS/update_book.sh" rating "$2" "$3" &&
            echo "Rated $(bash "$BOOKS/book_details.sh" "$2" | cut -d',' -f1): $3 out of 5" ;;
    set-status)
        bash "$BOOKS/update_book.sh" status "$2" "$3" &&
            echo "$(bash "$BOOKS/book_details.sh" "$2" | cut -d',' -f1) is now: $3" ;;

    # add TITLE AUTHOR: User Input → Metadata → Database
    add)
        if [[ -z "$2" || -z "$3" ]]; then
            echo "Error: a title and an author are required" >&2
            exit 1
        fi
        # Skip the online lookup if the book is already in the library
        if bash "$BOOKS/book_details.sh" "$2" > /dev/null; then
            echo "This book already exists"
            exit 1
        fi
        IFS=',' read -r title author genre <<< "$(bash "$BOOKS/fetch_book_metadata.sh" "$2" "$3")"
        bash "$BOOKS/add_book.sh" "$title" "$author" "$genre" &&
            echo "Added $title by $author ($genre)" ;;

    *)
        echo "Usage: manage_library.sh list | search TERM | status STATUS | details TITLE | rate TITLE 1-5 | set-status TITLE STATUS | add TITLE AUTHOR" >&2
        exit 1 ;;
esac
