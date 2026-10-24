# Base method (when a phase has no skill)

| Phase | Base method |
|---|---|
| Brainstorm | One question at a time on goal, users, constraints and what's out; propose 2-3 approaches with pros and cons; write a short spec and get it approved |
| Plan | Small independent tasks, each with files, steps, verification command and executor; ordered by dependencies; saved to a file and approved |
| Claude's tasks | One task at a time; after each: verify, commit, update the plan |
| Codex isolation | The `codex-run` script (it creates the worktree) |
| Review | Does it do what the task asked? Verification passes? No secrets or work files in the diff? No files outside the scope? Style consistent? Edge cases and errors handled? |
| Final check | Run all verification commands, check each requirement, show the evidence; never claim done without it |
