Run your merge cycle:
1. Search Jira CPT-3 for issues in Done state with unmerged feature branches
2. For each: verify CI green on the feature branch, merge to main, push, delete the feature branch
3. Check for merge conflicts between pending feature branches and main.
