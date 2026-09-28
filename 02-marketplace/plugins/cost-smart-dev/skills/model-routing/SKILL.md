---
name: model-routing
description: Company rulebook for picking the cheapest model and agent that can do a task well. Use at the start of any multi-step task, whenever moving between phases (research, planning, design, implementation, testing, review, docs), and before delegating work to a subagent.
---

# Model routing rulebook

Goal: do every task on the cheapest model that does it well. Price per token is roughly
**Haiku 1 : Sonnet 3 : Opus 5**. A wrong cheap choice that needs redoing costs more than
the right choice first time, so follow the table rather than always picking the cheapest.

## 1. Route by task type

| If the task is… | Send it to | Model |
|---|---|---|
| Find where something is, read many files, summarize docs, "how does X work?" | `researcher` | Haiku |
| Run build / tests / lint, read long logs or stack traces | `test-runner` | Haiku |
| READMEs, comments, doc comments, changelog, PR description | `doc-writer` | Haiku |
| API contract, entity shape, screen/component structure for one feature | `designer` | Sonnet |
| Write or change code (feature, bug fix, refactor) | `implementer` | Sonnet |
| SQL, EF Core, Cosmos DB, Databricks, PySpark, pipelines | `data-engineer` | Sonnet |
| Write tests | `test-writer` | Sonnet |
| Everyday review of a diff | `code-reviewer` | Sonnet |
| New project / large feature plan, choose between approaches, cross-service design, AI system design | `architect` | Opus |
| Auth, permissions, payments, personal data, secrets, crypto, uploads, LLM prompt handling, cloud IAM, pre-release | `security-reviewer` | Opus |

## 2. Always Opus, never downgrade

- Security review of the sensitive areas in the last row.
- Architecture decisions that are expensive to reverse (data model of a core entity, service boundaries, public API contracts).

## 3. Never Opus

- Formatting, renames, moving files, small obvious fixes, generating boilerplate, writing docs, running tests, reading logs.

## 4. Do it yourself (no subagent) when

- The task is small: one file, under ~50 lines, and you already have the context.
- The question can be answered from what is already in the conversation.

Every subagent starts with an empty context and re-reads files, so delegating tiny tasks costs more than it saves.

## 5. Escalation

- If a Haiku agent fails or gives a weak answer **once**, redo it with the Sonnet-level agent for that job (or pass `model: "sonnet"` when invoking).
- If a Sonnet agent fails the **same** task twice, send it to `architect` for a diagnosis and plan, then back to `implementer`.
- Never escalate straight from Haiku to Opus for coding work.

## 6. When you use a general-purpose subagent

The company default for unnamed subagents is Haiku. When a general-purpose subagent must
**write or change code**, pass `model: "sonnet"` in that invocation. For read-only work leave the default.

## 7. Keep context small (this saves as much as model choice)

- Prefer a plan file over re-explaining: planning writes `docs/ai/plan.md`; later phases read it.
- Ask subagents for short summaries with `file:line` references, never whole files.
- When a phase ends, run the `handoff` skill, then suggest the user runs `/clear` and starts the next phase from `docs/ai/handoff.md`.

## 8. Typical flow for a feature

1. `researcher` (Haiku): map the relevant code.
2. `architect` (Opus): write `docs/ai/plan.md`. Skip this for small, clear tasks.
3. `designer` (Sonnet): only if there is a new API, data shape or screen.
4. `implementer` / `data-engineer` (Sonnet): one plan step at a time.
5. `test-writer` (Sonnet), then `test-runner` (Haiku).
6. `code-reviewer` (Sonnet); plus `security-reviewer` (Opus) if any sensitive area was touched.
7. `doc-writer` (Haiku).
