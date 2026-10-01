#!/bin/bash
# Workflow layer: coordinate recommendation agents.


REC="$(dirname "${BASH_SOURCE[0]}")/../recommendations"
choice="${1:-all}"
interests="$2"

# Which agents to run
case "$choice" in
    history|interests|discovery) names=("$choice") ;;
    all)                         names=(history interests discovery) ;;
    *)
        echo "Usage: get_recommendations.sh history | interests INTERESTS | discovery | all INTERESTS" >&2
        exit 1 ;;
esac

# Run one agent: rows go to a temp file, messages to a log file (kept off the screen).
# stdin is /dev/null so a background agent can't stop to ask a question.
run_agent() {
    case "$1" in
        history)   bash "$REC/recommend_from_history.sh" ;;
        interests) bash "$REC/recommend_from_interests.sh" "$interests" ;;
        discovery) bash "$REC/recommend_for_discovery.sh" ;;
    esac > "$tmp/$1" 2> "$tmp/$1.log" < /dev/null
}

# Draw the progress display (stderr): a bar of finished agents, then one line per agent:
#   [██████████░░░░░░░░░░] 1/2 agents done
#   ⠹ history     searching... 3s
#   ✓ interests   done in 0.91s
frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
draw_progress() {
    local frame="${frames[$1]}" total=${#names[@]} bar="" i secs
    local done_count=$((total - remaining))
    local filled=$((done_count * 20 / total))

    for ((i = 0; i < 20; i++)); do
        if [[ $i -lt $filled ]]; then bar+="█"; else bar+="░"; fi
    done
    printf '\033[2K  [%s] %d/%d agents done\n' "$bar" "$done_count" "$total" >&2

    for i in "${!names[@]}"; do
        case "${state[i]}" in
            running)
                printf '\033[2K  %s %-10s  searching... %ds\n' "$frame" "${names[i]}" "$SECONDS" >&2 ;;
            done)
                # The agent's last line is its timer: "#elapsed,1.23"
                secs="$(tail -n 1 "$tmp/${names[i]}" | cut -d',' -f2)"
                printf '\033[2K  \033[32m✓\033[0m %-10s  done in %ss\n' "${names[i]}" "$secs" >&2 ;;
            failed)
                # Show the agent's last message as the reason
                printf '\033[2K  \033[31m✗\033[0m %-10s  %s\n' "${names[i]}" "$(tail -n 1 "$tmp/${names[i]}.log")" >&2 ;;
        esac
    done
}

# One temp file per agent, so their outputs never mix
tmp="$(mktemp -d)"
# Hide the cursor during the animation; always restore it on exit
trap 'rm -rf "$tmp"; printf "\033[?25h" >&2' EXIT
printf '\033[?25l' >&2

# 1. Start the agents in the background
SECONDS=0
for i in "${!names[@]}"; do
    run_agent "${names[i]}" &
    pids[i]=$!
    state[i]=running
done

# 2 & 3. Poll until every agent finishes, redrawing the display each pass
remaining=${#names[@]}
tick=0
while true; do
    for i in "${!names[@]}"; do
        [[ "${state[i]}" != running ]] && continue
        kill -0 "${pids[i]}" 2>/dev/null && continue     # still running

        # wait collects the finished agent's exit status
        if wait "${pids[i]}"; then state[i]=done; else state[i]=failed; fi
        remaining=$((remaining - 1))
    done

    # Move the cursor up so the new drawing overwrites the last one
    [[ $tick -gt 0 ]] && printf '\033[%dA' $((${#names[@]} + 1)) >&2
    draw_progress $((tick % ${#frames[@]}))
    tick=$((tick + 1))

    [[ $remaining -eq 0 ]] && break
    sleep 0.1
done

# 4 & 5. Tag rows with the agent name, combine, and refine
for name in "${names[@]}"; do
    sed "s/^/$name,/" "$tmp/$name"
done | bash "$REC/refine_recommendations.sh"
