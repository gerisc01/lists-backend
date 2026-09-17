---
name: comment-review
description: "Audit comments on the branch diff (or a given file or directory) against the house rule by verifying their claims against the code, then keep, rewrite, or cut each one. Use for a comment cleanup pass."
priority: high
allowed-tools: "Bash, Read, Edit, Grep, Glob"
---

# Comment Review for lists-backend

Exists because comment cleanup done as prose editing preserves false claims and makes them
more confident. A comment cannot be judged from its own text — only against the code it
describes. `scripts/comment_audit.rb` is the inventory; this skill is the judgment.

| Invocation | Reviews |
|---|---|
| `/comment-review` | comments added or changed on this branch: `git diff main...HEAD` plus uncommitted changes |
| `/comment-review <path>` | every comment in that file or directory |
| `... --report` | same, but edit nothing — `/review-pr` uses this |

On a diff, review only the changed comment blocks, but read the code they sit on in full.

**Applied:** keep / rewrite / cut on a checked claim, and fixing a refuted one.
**Left for you:** suggested additions, and any claim marked *not chased*.

Code style is out of scope — that is `/style-review`, which runs first.

## The rules a comment must pass

1. **Names a mechanism, not a consequence.** Consequences follow from mechanisms; the reverse
   is not recoverable. `` `end_date` is inclusive `` over "this week stays actionable".
   The mirror also holds: a true mechanism with no consequence *in this file* is noise. Point
   at the line it explains, and never borrow a concept the file does not model (a hook with no
   press handling cannot have a double-tap) to invent one.
2. **The mechanism is a fact about the world, not a decision about the arrangement.** A data
   model, a server guarantee, another module's behavior — things rewriting this file cannot
   change. "Route everything through this seam" is design rationale however hard it is to
   derive, and design rationale is banned. If the next line already says it, cut.
3. **No dead references, past tense, or roads not taken.** `docs/`, `DECISIONS`, PR numbers,
   issue ids; "used to", "the old gate"; "the alternative would be".
4. **≤ 2 lines**, and **anchored to the narrowest code it explains.** A comment above a function
   claims to be about the function. If the fact actually bears on one clause inside it, put it on
   that clause — and split a block whose parts explain different lines. A function-level comment
   is right only when the fact is about the function as a whole.
5. **Write for someone glancing, not studying.** The reader is passing through an unfamiliar file.
   Use the official names from the code, then hand them a shortcut to what those names mean — "a
   ghost is a repeating event the board draws but hasn't saved" beats "a ghost is a projection,
   not a row" in the same space. Short means fewer words, never denser ones: if the plain-English
   version would take a sentence to explain to someone new, that sentence *is* the comment.

A path to a file that still exists is a mechanism, not a dead reference. Check before cutting.

**Exempt from the 2-line limit:** a script's header when it acts as the script's README — why it
exists and how to run it. Rules 1–3 still apply to it.

## Procedure

Per file:

1. **Inventory** — `ruby scripts/comment_audit.rb --list <path>`, then
   `ruby scripts/comment_audit.rb --leads` for comments naming things that no longer exist and
   exports nothing calls. Both are enumeration, which is what a script is for — spending your
   own reading on it is the wrong use of the budget. Its output is leads, never verdicts: a
   clean run says nothing about whether a comment is true, and a hit is a place to go read.
2. **Read the code first, then the comment.** Reversing this leads to compressing the comment's
   claims instead of deriving them from the code.
3. **Extract every claim and give each a verdict** (see below). Do this before deciding
   keep/rewrite/cut — a claim's truth is not a matter of taste, and an unverified claim is the
   dangerous kind.
4. **Decide** keep / rewrite / cut against the five rules.
5. **A refuted claim is a finding about the code.** Open an issue (`gh issue create -R
   gerisc01/games-lists`, `be` and `loe:` labels, `Done when:` line). A wrong comment is usually the
   visible end of dead or duplicated code.
6. **Report the evidence.** Cite `file:line` for what backed each kept comment.
7. **Suggest, never add.** Where changed code seems to need a fact from outside the file, list it
   as a suggestion: `file:line`, the fact, and where it lives. Say what you read — the gap may be
   your narrow context, not the code. A person decides. Tangled code is a `/style-review` finding.

## Verdicts

Every comment worth keeping makes a checkable claim about something else. Classify, then check:

| The comment claims | Check |
|---|---|
| a symbol behaves some way | grep it, read it |
| a file exists | `ls` it |
| a caller or UI path exists | grep for callers |
| the server does X | find the test in `test/` that pins it |
| the client does X | read `../games-lists/src/`, or mark it *not chased* if that checkout is absent |
| another module behaves some way | read that module |
| *nothing external* | it is restating code — cut |

That last row makes this one pass rather than two: **a comment with no externally verifiable
claim is almost always narrating the code.**

Each claim gets one of:

- **verified** — with the `file:line` that backs it
- **refuted** — the comment is wrong; fix it and open an issue for the code
- **not chased** — with the reason. A legitimate answer; a silent skip is not.

## Reporting

Present a table of blocks with claim, verdict, evidence, and decision (keep / rewrite / cut), so
the result can be audited without re-reading the file. Suggested additions go in a separate list.

**Never cite a comment-only diff or a passing test suite as evidence a comment is accurate.**
Both are green by construction for any comment, true or false. They prove the edit was safe,
not that it was correct.

## Verify the edit was comment-only

After editing: `ruby scripts/comment_audit.rb --verify` — proves code is identical once
comments are stripped. This is a safety check on the diff, not a check on the claims.
