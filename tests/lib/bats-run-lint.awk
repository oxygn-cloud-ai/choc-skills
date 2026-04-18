# bats-run-lint.awk — tokenize `run ...` lines in .bats files and flag
# top-level argv tokens that start with `<` (stdin-redirect-as-argv bug).
#
# Replaces the grep+filter+union chain from CPT-162/165/167/168 (which
# accumulated four Codex-caught refinements in 48 hours) with a
# quote-state-tracking tokenizer.
#
# Flag rule (matches CPT-168 behaviour exactly, with escape-handling fixed):
#   A top-level unquoted token T is an offender iff:
#     length(T) >= 2
#     AND T[0] == '<'
#     AND T[1] not in {'|', '(', '<'}
#
# Exclusions mean:
#   `<file`       → flagged (bug)
#   `<<EOF`       → NOT flagged at top level (CPT-168 scope choice)
#   `<(proc)`     → NOT flagged (process substitution)
#   `<|pipe`      → NOT flagged (degenerate shell pipe shape)
#   `<` alone     → NOT flagged (len 1; matches CPT-168 regex `[^ |(<]` which
#                    required at least one char after `<`)
#
# Tokenizer state machine (per line):
#   0 = outside quotes
#   1 = inside single quotes (no escaping — shell semantics)
#   2 = inside double quotes (backslash escapes)
#
# Inside double quotes, `\X` (any char) is consumed as a 2-char escape
# unit. This is the fix for CPT-169: the old grep regex `"[^"]*"` treated
# `\"` as a closing quote and broke tokenization of `bash -c "echo \"x\"
# <file"` where `<file` is inner-shell-legitimate.
#
# Output: `<filename>:<line-number>:<line-text>` for each offender.
# Matches `grep -n` format so downstream error rendering is unchanged.

function tokenize_and_flag(line,    i, c, state, token, n, tokens, len, j, t, t1, t2, cs_depth) {
    state = 0
    token = ""
    n = 0
    cs_depth = 0
    len = length(line)

    # Skip leading whitespace.
    i = 1
    while (i <= len && substr(line, i, 1) ~ /[[:space:]]/) i++

    # Line must start with "run" followed by ANY whitespace (space or tab).
    # CPT-170: the previous literal `"run "` check required a space and
    # silently accepted no match on `run\tcat ...` — a false negative for
    # a valid shell syntax.
    if (substr(line, i, 3) != "run") return 0
    i += 3
    if (i > len) return 0
    if (substr(line, i, 1) !~ /[[:space:]]/) return 0
    i++

    while (i <= len) {
        c = substr(line, i, 1)

        if (state == 0) {
            # CPT-172: command substitution `$(...)` and arithmetic
            # expansion `$((...))` are single shell words — the whole
            # span is concatenated with whatever follows (including any
            # `#suffix`). Detect entry via `$(` lookahead and stay in
            # cs-mode until paren depth returns to 0. Inside cs-mode,
            # ALL chars append to token — no operator flushes, no
            # whitespace splits. Arithmetic `$((` naturally handled by
            # the second `(` bumping depth to 2; matched by `))`.
            if (c == "$" && i < len && substr(line, i + 1, 1) == "(") {
                token = token "$("
                cs_depth++
                i += 2
                continue
            }
            if (cs_depth > 0) {
                # Inside command subst / arithmetic — append literally
                # and track paren depth. Quotes inside are not strictly
                # tracked here (they'd need full recursive parsing); for
                # the `<`-start rule the whole span becomes one token
                # regardless, so depth tracking alone is sufficient.
                token = token c
                if (c == "(") cs_depth++
                else if (c == ")") cs_depth--
                i++
                continue
            }
            # Outside quotes and outside cmd-subst.
            # CPT-170: `#` only starts a comment at a word boundary
            # (token is empty — we just crossed whitespace or we're at
            # start). Inside a word, `#` is a literal char. POSIX shell
            # semantics.
            # CPT-171: shell operators (`;`, `|`, `&`, `(`, `)`) are
            # ALSO word boundaries — after them, `#` starts a comment.
            # The operator cases below flush the current token, so the
            # `token == ""` guard here fires correctly on the next iter.
            if (c == "#" && token == "") break
            if (c == " " || c == "\t") {
                if (token != "") { n++; tokens[n] = token; token = "" }
                i++
                continue
            }
            # CPT-171: shell operator flush. `;`, `|`, `&`, `(`, `)` are
            # shell-syntax token terminators; the shell starts a new
            # command context after them. Flush the current token and
            # advance past the operator char; do NOT emit the operator
            # into tokens[] — it's not argv and emitting it would add
            # noise to the `<`-start rule.
            # Note: `(` outside `$(` is a subshell opener (legitimate
            # operator boundary); `$(` is handled above, so by the time
            # we reach this branch, a bare `(` really is a subshell.
            if (c == ";" || c == "|" || c == "&" || c == "(" || c == ")") {
                if (token != "") { n++; tokens[n] = token; token = "" }
                i++
                continue
            }
            if (c == "'")  { state = 1; token = token c; i++; continue }
            if (c == "\"") { state = 2; token = token c; i++; continue }
            # Top-level backslash escape — consume both chars as literal.
            if (c == "\\" && i < len) {
                token = token substr(line, i, 2)
                i += 2
                continue
            }
            token = token c
            i++
            continue
        }

        if (state == 1) {
            # Inside single quotes — no escaping; `'` always closes.
            if (c == "'") state = 0
            token = token c
            i++
            continue
        }

        if (state == 2) {
            # Inside double quotes — `\X` is a 2-char escape unit.
            if (c == "\\" && i < len) {
                token = token substr(line, i, 2)
                i += 2
                continue
            }
            if (c == "\"") state = 0
            token = token c
            i++
            continue
        }
    }

    # End of line — flush any pending token.
    if (token != "") { n++; tokens[n] = token }

    # Examine each top-level token. Tokens whose FIRST character is a quote
    # are quoted arguments (e.g. `"cat <file"`) — the `<` is inside quotes
    # at the argv level, not at the top level, so not a bug.
    for (j = 1; j <= n; j++) {
        t = tokens[j]
        t1 = substr(t, 1, 1)
        if (t1 != "<") continue
        if (length(t) < 2) continue  # bare `<` alone — matches CPT-168's `[^ |(<]` floor.
        t2 = substr(t, 2, 1)
        if (t2 == "|" || t2 == "(" || t2 == "<") continue  # pipe / process-subst / heredoc
        return 1
    }
    return 0
}

{
    if (tokenize_and_flag($0)) {
        print FILENAME ":" FNR ":" $0
    }
}
