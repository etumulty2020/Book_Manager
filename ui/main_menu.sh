#!/bin/bash
# UI layer: main application menu.
UI="$(dirname "${BASH_SOURCE[0]}")"

while true; do
    clear
    gum style --border double --padding "1 4" --foreground 212 --bold "📚 Book Manager"

    choice=$(gum choose "Browse Library" "Get Recommendations" "Quit")

    case "$choice" in
        "Browse Library")
            bash "$UI/library_screen.sh" ;;

        "Get Recommendations")
            bash "$UI/recommendations_screen.sh" ;;

        *) break ;;   # "Quit" or Esc
    esac

    gum input --placeholder "Press Enter to return to the menu" > /dev/null
done
