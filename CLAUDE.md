# CLAUDE.md

The HTTP API behind games-lists (Sinatra/Ruby). Frontend: `../games-lists`, which holds `NEXT.md`
and the issue backlog for both repos.

| Read | For |
|---|---|
| [README.md](README.md) | run, test, how it works, where changes go |
| [SCHEMA.md](SCHEMA.md) | what the `ruby-schema` gem generates for each type |
| [PR_GUIDE.md](PR_GUIDE.md) | PR size and template |
| `../games-lists/NEXT.md` | what's next — backlog is GitHub issues labelled `be` (`gh issue list -R gerisc01/games-lists -l be`) |

## Rules

- **Next steps live in `../games-lists/NEXT.md`, never in memory.** Backend work gets an issue there
  with the `be` label, a `Done when:` line, and a `loe:S/M/L` label.
- **Docs describe the current state only.** No history, no "we used to", no decision logs. When code
  changes what `README.md` or `SCHEMA.md` says, update them in the same PR.
- **Comments are rare.** Only for the unusual or easy-to-miss, ≤ 2 lines. Never design rationale,
  refactor steps, PR numbers, or doc references. A script's header may run longer when it's the
  script's README.
- **Always `bundle exec`.** A bare `rake` picks up the wrong Sinatra and every API test fails with
  `400 Host not permitted`.
- Routes stay thin; logic lives in `src/actions/`.

## How to write here

Applies to docs, plans, and options written in a session. Length is a cost.

- **Show the shape, then stop.** A table, diagram, or example beats the paragraph describing it.
- **Name the decision point; pick one.** Give the one reason. Don't survey the rest.
- **Explain once.** No restated caveats, no background the reader already has.
- **Trust the reader to ask.**

## Tooling

Being rebuilt (`../games-lists/NEXT.md` item 1, step 3).

| Tool | Does |
|---|---|
| `test.sh` | run all tests, one file, or one test |
| `scripts/instance_loop.rb` | drive the instance loop end to end against the e2e server |

Doing something for the third time? Make it a script in `scripts/` or a skill in `.claude/skills/`,
with a header comment saying why it exists, and list it here.
