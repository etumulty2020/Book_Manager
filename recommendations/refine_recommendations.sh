#!/bin/bash
# Recommendation component: read candidates from stdin and produce a refined shortlist.

# Input (stdin):   source,title,author,genre,status,rating,link   (one per candidate)
#                  source,#elapsed,SECONDS                        (one per agent)
# Output (stdout): up to 3 books per agent under a heading with the agent's time,
#                  as books.csv rows (title,author,genre,status,rating,link)


source "$(dirname "${BASH_SOURCE[0]}")/../data/book_database.sh"

per_list=3

# Inputs: the library's titles first, then the candidates from stdin
awk -F',' -v OFS=',' '
    # Comparison key: lowercase, no subtitle ("Frankenstein; or ..." = "Frankenstein")
    function key(t) {
        t = tolower(t)
        sub(/[;:(].*/, "", t)
        gsub(/^ +| +$/, "", t)
        return t
    }

    # Capitalise each word: "machine learning" -> "Machine Learning"
    function title_case(s,    words, n, i, out) {
        n = split(s, words, " ")
        for (i = 1; i <= n; i++)
            out = out (i > 1 ? " " : "") toupper(substr(words[i], 1, 1)) substr(words[i], 2)
        return out
    }

    BEGIN { list_order["history"] = 1; list_order["interests"] = 2; list_order["discovery"] = 3 }

    # First input: every title already in the library
    FNR == NR { in_library[key($0)] = 1; next }

    # Second input: the candidates
    {
        src = $1; title = $2; author = $3; genre = $4

        # Timer line: remember how long the agent took
        if (title == "#elapsed") { elapsed[src] = $3; next }

        k = key(title)

        # Skip blank lines, a header row, box sets, and books with no known author
        if (k == "" || k == "title" || title ~ / \/ / || author == "Unknown") next

        # 2. Skip books already in the library
        if (k in in_library) next

        # 1. Count repeats instead of keeping them; the first copy (and its list) wins
        if (!(k in times)) {
            order[++n] = k
            # 4. Polish: keep the main title only, trim spaces, capitalise the genre
            clean = title
            sub(/ *[;:(].*/, "", clean)
            gsub(/^ +| +$/, "", clean)
            best_src[k] = src
            best_title[k] = clean
            best_author[k] = author
            best_genre[k] = title_case(genre)
        }
        times[k]++
    }

    # 3. Put list number, repeat count and arrival position in front, for sorting
    END {
        # Timer lines get a huge count so they sort first in their list
        for (s in elapsed)
            print ((s in list_order) ? list_order[s] : 9), 999999, 0, s, "#elapsed", elapsed[s]

        for (i = 1; i <= n; i++) {
            k = order[i]
            s = best_src[k]
            t = best_title[k]; a = best_author[k]
            link = "https://www.google.com/search?tbm=bks&q=" t " " a
            gsub(/ /, "%20", link)
            print ((s in list_order) ? list_order[s] : 9), times[k], i, s, t, a, best_genre[k], "want_to_read", "", link
        }
    }
' <(list_titles) - |
    sort -t',' -k1,1n -k2,2nr -k3,3n |     # by list, then most-suggested, then arrival order
    awk -F',' -v per_list="$per_list" '
        # Print a heading before each list (with the agent time, if it sent one)
        function heading(src, secs) {
            if (headed[src]++) return
            if (NR > 1) print ""
            print toupper(substr(src, 1, 1)) substr(src, 2) " recommendations" \
                (secs != "" ? " (took " secs "s)" : "") ":"
        }

        # A timer line comes first, so its heading can show the time
        $5 == "#elapsed" { heading($4, $6); next }

        # Keep the first few books of each list
        {
            src = $4
            if (++shown[src] > per_list) next
            heading(src, "")
            sub(/^[^,]*,[^,]*,[^,]*,[^,]*,/, "")    # drop list, count, position and source
            print
        }'
