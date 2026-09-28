# Claude Code: 7 habits that save money (one page)

Our setup already picks cheaper models for you. These habits save another ~20% on top.

1. **Start each phase fresh.** When you finish research, planning, coding or testing, say
   *"hand off"* (runs the `handoff` skill), then type `/clear`, then *"Continue from docs/ai/handoff.md"*.
   A long chat re-sends all its history on every message, so you pay for it again and again.

2. **Let the default model work.** Your default is `opusplan`: Opus while planning (Shift+Tab into plan mode), Sonnet while coding.
   Only switch to `/model opus` for a genuinely hard problem, and switch back after.

3. **Name the agent when you know it.** "Use the researcher to find where invoices are calculated",
   "use test-runner", "use security-reviewer on this diff". Cheap agents do the reading; expensive ones do the thinking.

4. **Plan big work once, in a file.** For anything bigger than a small fix, ask the architect for
   `docs/ai/plan.md`, then implement it step by step. Do not re-explain the task every session.

5. **Keep CLAUDE.md short.** Under ~60 lines. It is loaded on every single turn.

6. **Point, don't paste.** Give file paths (`src/Api/InvoiceController.cs:120`) instead of pasting big files or whole logs.
   Paste only the few error lines that matter.

7. **Stop runaway work early.** If Claude is going in circles, press Esc, correct it in one sentence, or `/clear` and restart from the handoff.

**Always use `security-reviewer` (Opus) for:** login/auth, permissions, payments, personal data, secrets, file uploads, AI prompt handling.
