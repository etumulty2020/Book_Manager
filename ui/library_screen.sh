#!/bin/bash
# UI layer: display library information.
WORKFLOW="$(dirname "${BASH_SOURCE[0]}")/../workflows/manage_library.sh"

while true; do
    gum style --border rounded --padding "0 2" --foreground 212 "My Library"

    choice=$(gum choose "All books" "Search" "Books by status" "Book details" "Rate book" "Update status" "Add book" "Back")

    case "$choice" in
        "All books")
            # Ratings 1-5 show as stars (★★★★☆); anything else shows as "–"
            bash "$WORKFLOW" list | awk -F',' -v OFS=',' '{
                stars = "–"
                if ($4 ~ /^[1-5]$/) {
                    stars = ""
                    for (i = 1; i <= 5; i++) stars = stars (i <= $4 ? "★" : "☆")
                }
                print $1, $2, $3, stars, $5
            }' | gum table --print --columns "Title,Author,Status,Rating,Series" ;;

        "Search")
            term=$(gum input --placeholder "Title or author")
            results=$(bash "$WORKFLOW" search "$term")
            echo "${results:-No books found.}" | gum style --padding "0 2" ;;

        "Books by status")
            book_status=$(gum choose finished reading want_to_read owned)
            bash "$WORKFLOW" status "$book_status" | gum style --padding "0 2" ;;

        "Book details")
            title=$(gum input --placeholder "Exact book title")
            if row=$(bash "$WORKFLOW" details "$title"); then
                IFS=',' read -r t author genre book_status rating link series <<< "$row"
                # "-" in books.csv means the book isn't part of a series
                [[ "${series%$'\r'}" == "-" ]] && series="Not part of a series"
                gum style --border normal --padding "1 2" \
                    "Title:  $t" "Author: $author" "Genre:  $genre" \
                    "Status: $book_status" "Rating: $rating" "Series: $series" "Link:   $link"
            else
                gum style --foreground 196 "No book found with that title."
            fi ;;

        "Rate book")
            title=$(gum input --placeholder "Title of the book to rate")
            if ! row=$(bash "$WORKFLOW" details "$title"); then
                gum style --foreground 196 "No book found with that title."
            else
                # Show the saved row so the user can confirm it's the right book
                gum style --border normal --padding "0 1" "${row%$'\r'}"
                if gum confirm "Is this the book you want to rate?"; then
                    rating=$(gum input --placeholder "Rating from 1 to 5")
                    bash "$WORKFLOW" rate "$title" "$rating" 2>&1 | gum style --padding "0 2"
                fi
            fi ;;

        "Update status")
            title=$(gum input --placeholder "Title of the book to update")
            if ! row=$(bash "$WORKFLOW" details "$title"); then
                gum style --foreground 196 "No book found with that title."
            else
                # Show the saved row so the user can confirm it's the right book
                gum style --border normal --padding "0 1" "${row%$'\r'}"
                if gum confirm "Is this the book you want to update?"; then
                    new_status=$(gum choose --header "New status" finished reading want_to_read owned)
                    [[ -n "$new_status" ]] &&
                        bash "$WORKFLOW" set-status "$title" "$new_status" 2>&1 | gum style --padding "0 2"
                fi
            fi ;;

        "Add book")
            title=$(gum input --placeholder "Title")
            author=$(gum input --placeholder "Author")
            # Spinner while the workflow looks up the genre online
            gum spin --title "Looking up book details..." --show-output -- \
                bash "$WORKFLOW" add "$title" "$author" ;;

        *) break ;;   # "Back" or Esc
    esac
    echo
done
