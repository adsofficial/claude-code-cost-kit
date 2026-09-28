---
name: handoff
description: Saves the current state of the work to docs/ai/handoff.md so the conversation can be cleared and the next phase started cheaply. Use when a phase is finished (research, planning, design, implementation, testing, review), when the conversation has grown long, or when the user asks to hand off, save progress, or start fresh.
---

# Phase handoff

Long conversations are expensive: every new message re-sends the whole history.
A handoff file lets the user run `/clear` and continue with a small context.

## Steps

1. Write (or overwrite) `docs/ai/handoff.md` with exactly these sections, as short bullet points:

   ```markdown
   # Handoff: <feature or task name>
   Updated: <date>

   ## Goal
   ## Done so far
   ## Key decisions (and why)
   ## Files that matter
   - path/to/file.ext: what it is / what changed
   ## Next step
   - The single next action, and which agent should do it
   ## Open questions / risks
   ```

2. Keep it under 60 lines. Link to `docs/ai/plan.md` and any `docs/ai/design-*.md` instead of copying them.
3. Do not include secrets, tokens, connection strings or personal data.
4. Tell the user, in one or two lines:
   - The handoff is saved at `docs/ai/handoff.md`.
   - To continue cheaply: run `/clear`, then say "Continue from docs/ai/handoff.md".

## Resuming

When asked to continue from a handoff, read `docs/ai/handoff.md` (and the plan file it links)
first, then follow the `model-routing` skill for the next step. Do not re-research what the
handoff already records.
