#!/bin/bash
# UI layer: display recommendation progress and final results.
WORKFLOW="$(dirname "${BASH_SOURCE[0]}")/../workflows/get_recommendations.sh"

gum style --border rounded --padding "0 2" --foreground 212 "Recommendations"

# Pick which agent(s) to run
choice=$(gum choose --header "What kind of recommendations?" \
    "History" "Interests" "Discovery" "All (run in parallel)")

case "$choice" in
    "History")   agent="history" ;;
    "Interests") agent="interests" ;;
    "Discovery") agent="discovery" ;;
    "All (run in parallel)") agent="all" ;;
    *)           exit 0 ;;    # Esc
esac

# Only the interests agent (alone or in "all") needs interests
interests=""
if [[ "$agent" == "interests" || "$agent" == "all" ]]; then
    interests=$(gum input --placeholder "Your interests, topics, or fields (comma-separated)")
    # Required for Interests alone; "all" still runs the other two without them
    if [[ -z "$interests" && "$agent" == "interests" ]]; then
        gum style --foreground 196 "No interests entered."
        exit 0
    fi
fi

# Progress (stderr) shows live in the terminal; the lists (stdout) are captured to display
results=$(bash "$WORKFLOW" "$agent" "$interests")
echo

if [[ -z "$results" ]]; then
    gum style --foreground 196 "No recommendations found."
    exit 0
fi

# Each list is a heading line followed by books.csv rows:
#   History recommendations (took 1.46s):
#   title,author,genre,status,rating,link
while IFS= read -r line; do
    if [[ -z "$line" ]]; then
        echo
    elif [[ "$line" == *recommendations*: && "$line" != *,* ]]; then
        gum style --foreground 212 --bold "$line"
        n=0
    else
        IFS=',' read -r title author genre _ <<< "$line"
        n=$((n + 1))
        echo "  $n. $title by $author ($genre)"
    fi
done <<< "$results"
