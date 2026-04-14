Run your audit cycle:
1. Check for new commits on main since last audit (refs/audit/chk1-last-seen)
2. If new commits found: run /chk1:all against each new diff
3. File findings as Jira tasks under CPT-3 with type Code Quality, priority P1-P4
4. Deduplicate: search Jira CPT-3 before filing, update existing if match
5. Update last-seen SHA
