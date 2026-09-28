# Claude Code Cost Kit — full details

This document explains **why** the kit is built the way it is, **what every file does**, and
**the full cost math** behind the savings estimate. The [README](README.md) is the short
version for getting it installed; this is the long version for understanding it, tuning it,
and answering questions from your team or your finance department.

---

## Table of contents

1. [The problem this kit solves](#1-the-problem-this-kit-solves)
2. [Why not a runtime "router" subagent](#2-why-not-a-runtime-router-subagent)
3. [Architecture: the three layers](#3-architecture-the-three-layers)
4. [Tokens vs. cost — the distinction that matters](#4-tokens-vs-cost--the-distinction-that-matters)
5. [The cost math, step by step](#5-the-cost-math-step-by-step)
6. [Every file in the kit, explained](#6-every-file-in-the-kit-explained)
7. [The 10 agents in depth](#7-the-10-agents-in-depth)
8. [The 3 skills in depth](#8-the-3-skills-in-depth)
9. [Managed settings: how Claude Code picks which policy applies](#9-managed-settings-how-claude-code-picks-which-policy-applies)
10. [Measuring the real saving (OpenTelemetry)](#10-measuring-the-real-saving-opentelemetry)
11. [Risks and how the kit guards against them](#11-risks-and-how-the-kit-guards-against-them)
12. [Tuning knobs, one by one](#12-tuning-knobs-one-by-one)
13. [FAQ](#13-faq)

---

## 1. The problem this kit solves

With 300+ developers on Claude Code across multiple projects (ASP.NET Core, Flutter,
React/Angular, TypeScript, Python, AI features, Databricks, Cosmos DB, SQL):

- Not everyone knows that **Haiku, Sonnet and Opus cost different amounts** (roughly 1 : 3 : 5
  per token), or which kind of task each one is good at.
- Left to individual choice, people default to the most capable model for everything —
  research, formatting, running tests, writing docs — even where a cheap model would do
  the job just as well.
- Nobody wants to be the person telling 300 developers "use Haiku for this, Sonnet for
  that" one Slack message at a time. It doesn't scale, and it doesn't stick.

The kit's goal: **make the cheap-and-correct choice the automatic one**, with nothing for a
developer to remember.

## 2. Why not a runtime "router" subagent

The original idea (from the earlier conversation) was a subagent that decides, at runtime,
which model a task needs. That's a reasonable instinct, but it runs into a hard limit in
how Claude Code works:

> **A subagent cannot change the model of the main session.**

Claude Code's main session is one long-running agent loop. A subagent is a *separate* agent
that the main session can delegate a sub-task to, and it returns a result — it never reaches
back and changes what model the main session itself is running on. So:

- If a developer's main session is on Opus, it **stays on Opus** for its own turns —
  reading files, planning, writing replies — no matter what any router subagent decides.
- In typical use, **60–80% of a session's tokens are spent in the main session**, not in
  subagents. A router can only affect the remaining 20–40%.
- A router subagent is itself an extra LLM call on every task, with its own cold start
  (subagents start with no memory of the conversation, so they often re-read files the
  main session already read). That overhead eats into the very savings it's trying to create.

Measured against "everyone stays on Opus, plus a router subagent for delegated work", the
saving is only about **10–25%** — better than nothing, but far short of what's actually
possible.

**What the kit does instead:** move the decision out of the runtime and into three places
that cost nothing to consult:

1. A **policy** that sets the main session's own default model sensibly (`opusplan`), so
   the manager itself is cheap by default.
2. **Agents with a model already baked into their definition** (`model: haiku` in the file),
   so there's no decision to make at invocation time — it's already decided.
3. A **rulebook skill** that Claude reads (a static file, no LLM call) before deciding which
   agent to delegate to.

This reaches the same destination as a smart router, without paying an LLM to get there
every time.

## 3. Architecture: the three layers

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Managed settings (deployed once, to every machine)  │
│  • Default model = opusplan (Opus for planning, Sonnet for   │
│    execution) — this fixes the 60-80% of tokens spent in the │
│    main session, which no agent or skill can reach.          │
│  • CLAUDE_CODE_SUBAGENT_MODEL = haiku (default for any       │
│    subagent that isn't one of the 10 named agents below)     │
│  • availableModels = [opus, sonnet, haiku] (Fable blocked)   │
│  • Marketplace registered + plugin force-installed           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: The cost-smart-dev plugin (one git repo, versioned) │
│  • 10 agents, each with model: haiku|sonnet|opus already in  │
│    its frontmatter — the choice is made at authoring time,   │
│    not at runtime.                                           │
│  • 3 skills: model-routing (the rulebook), handoff (context  │
│    control), stack-guides (correctness, so cheap models      │
│    don't produce wrong-but-plausible code)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Developer habits (one page, socialized in onboarding)│
│  • /clear between phases + handoff file                      │
│  • short CLAUDE.md per repo                                  │
│  • point to files, don't paste them                          │
└─────────────────────────────────────────────────────────────┘
```

Layer 1 is what makes this **organization-wide without relying on individual discipline**.
Layer 2 is what makes the model choice **correct without anyone having to think about it**.
Layer 3 is what captures the **remaining ~20%** that comes from smaller context rather than
cheaper tokens (see next section — these are two different levers).

## 4. Tokens vs. cost — the distinction that matters

This came up directly in the original conversation and is worth stating precisely, because
it's the thing that makes the whole kit make sense:

**Cost = number of tokens × price per token.** The price per token is *not* fixed — it
depends on:

| Factor | Effect on price |
|---|---|
| **Model** | Haiku : Sonnet : Opus ≈ 1 : 3 : 5 per token (rough historical ratio — check current pricing) |
| **Token type** | Output tokens (what the model writes) cost roughly 5× an input token; cached input tokens (text seen recently) cost roughly 0.1× |
| **Plan** | API billing charges per token directly; Team/Enterprise seats are a fixed price, and tokens instead count against a usage cap — Opus burns through that cap faster |

**Worked example — more tokens, lower cost:**

| Setup | Tokens used | Relative cost |
|---|---|---|
| A: everything on Opus | 1.0M | 1.0M × 5 = **5.0** |
| B: 0.8M on Haiku + 0.5M on Sonnet | 1.3M | (0.8M × 1) + (0.5M × 3) = **2.3** |

Setup B uses **30% more tokens** than setup A but costs **54% less**, because most of those
extra tokens ran on a model that's five times cheaper per token.

This is exactly why the router-subagent approach (which spends *more* tokens overall, once
you count the router's own overhead and any redone work) can still come out **cheaper**:
those extra tokens are landing on Haiku and Sonnet, not Opus.

**Practical takeaway for measuring the pilot (Step 6 in the README):** compare **cost**, not
token counts. A team whose total token count goes *up* after rollout can still be spending
significantly less, if the mix shifted toward cheaper models. Section 10 covers how to see
that mix directly.

## 5. The cost math, step by step

Take one developer using 10M tokens/month, with the illustrative price ratio Haiku : Sonnet :
Opus = 1 : 3 : 5.

**Baseline — everyone defaults to Opus (today, most likely state):**

```
10M tokens × 5  =  50 cost-units
```

**Step A — router subagent only** (the original idea from the earlier conversation).
The main session (60–80% of tokens) stays on Opus; only delegated work moves to cheaper
models, and the router itself adds overhead:

```
~39–42 cost-units   (16–22% saving)
```

**Step B — this kit's Layer 1 alone** (managed default → `opusplan`, subagents → Haiku
by default). The main session itself is now cheap by default:

```
~28 cost-units   (~43% saving)
```

**Step C — add Layer 2** (the 10 fixed-model specialist agents + the routing rulebook skill,
so work is *correctly* split across Haiku/Sonnet/Opus rather than defaulting to whatever the
main session happens to be on):

```
~27 cost-units   (~46% saving)
```

**Step D — add Layer 3** (habits: `/clear` + handoff between phases, short CLAUDE.md,
pointing at files instead of pasting them — roughly 20% fewer total tokens, on top of the
cheaper mix):

```
~22 cost-units   (~56% saving)
```

| Setup | Saving vs. all-Opus baseline |
|---|---|
| Router subagent only | 10–25% |
| + managed default (`opusplan` / Sonnet) | ~35–40% |
| + fixed-model agents + routing skill | **~45–60%** |
| + token habits | ~55–70% |

These numbers are **illustrative**, built from a rough historical price ratio and a typical
mix of task types. Your organization's actual saving depends on your real workload (how
much of it is research/docs/tests vs. hard architecture work) and your current pricing.
**Treat the pilot in Step 6 of the README as the source of truth**, not this table.

## 6. Every file in the kit, explained

```
claude-code-cost-kit/
├── README.md                                   Quick-start rollout guide
├── DETAILS.md                                  This file
│
├── 01-managed-settings/                        → IT deploys this once, org-wide
│   ├── managed-settings.json                   The policy (Azure DevOps marketplace variant)
│   ├── managed-settings.github-variant.json    Same policy, GitHub marketplace variant
│   ├── windows/Deploy-ClaudeCodePolicy.ps1     Copies the policy to the Windows system path,
│   │                                           validates JSON first, checks it's run elevated
│   └── macos/deploy-claude-policy.sh           Same, for macOS (Jamf/Kandji/Intune for Mac)
│
├── 02-marketplace/                             → Push the CONTENTS of this folder to its
│   │                                           own git repo (this is the plugin catalog)
│   ├── .claude-plugin/marketplace.json         Marketplace manifest: name + list of plugins
│   └── plugins/cost-smart-dev/                 The one plugin this kit ships
│       ├── .claude-plugin/plugin.json          Plugin manifest: name, version, description
│       ├── agents/                             10 agent definitions (see §7)
│       │   ├── researcher.md
│       │   ├── test-runner.md
│       │   ├── doc-writer.md
│       │   ├── designer.md
│       │   ├── implementer.md
│       │   ├── data-engineer.md
│       │   ├── test-writer.md
│       │   ├── code-reviewer.md
│       │   ├── architect.md
│       │   └── security-reviewer.md
│       └── skills/                             3 skills (see §8)
│           ├── model-routing/SKILL.md          The routing rulebook
│           ├── handoff/SKILL.md                Save-state-and-clear-context skill
│           └── stack-guides/
│               ├── SKILL.md                    Index — points to the right guide
│               └── references/
│                   ├── dotnet.md                ASP.NET Core / C# conventions, testing, security
│                   ├── flutter.md               Flutter / Dart conventions, testing, security
│                   ├── web.md                   React / Angular / TypeScript
│                   ├── python.md                Python
│                   ├── data.md                  SQL, EF Core, Cosmos DB, Databricks/PySpark
│                   └── ai.md                    LLM/AI features on Azure/Foundry, RAG, agents
│
└── 03-project-templates/                       → Copy into each individual project repo
    ├── CLAUDE.md.template                      A short, token-cheap CLAUDE.md starting point
    └── DEVELOPER-HABITS.md                     One-page habits sheet for developers
```

### Why the marketplace is a *separate* thing from the settings file

`01-managed-settings/` is **policy** — it's what tells every machine "go get the plugin
from here, and here's your default model." `02-marketplace/` is the **plugin itself** — the
actual agents and skills. They're separate because:

- The policy file is small and rarely changes; the plugin is where you'll actually iterate
  (tweaking an agent's prompt, adding a new stack guide).
- Hosting the plugin as its own git repo means `autoUpdate: true` in the policy lets you
  push a new agent to all 300 developers without touching the managed settings file again.
- If you ever want a second plugin (say, a company-specific one for a particular product
  line), it's a second entry in the same `marketplace.json`, no new policy rollout needed.

## 7. The 10 agents in depth

Each agent file is a markdown file with YAML frontmatter (`name`, `description`, `model`,
`tools`, etc.) followed by its system prompt. The **`model` field is the entire point** —
it's decided once, by whoever writes the agent, not at runtime.

| Agent | Model | Effort | Tools | Why this model |
|---|---|---|---|---|
| `researcher` | Haiku | — | Read, Grep, Glob, WebFetch, WebSearch | Finding and summarizing needs breadth, not deep reasoning |
| `test-runner` | Haiku | — | Bash, Read, Grep, Glob | Running commands and parsing pass/fail output is mechanical |
| `doc-writer` | Haiku | — | Read, Grep, Glob, Write, Edit | Documenting code that already exists and works is low-risk |
| `designer` | Sonnet | — | Read, Grep, Glob, Write, Edit | Designing one feature's API/data/UI shape needs real judgment |
| `implementer` | Sonnet | — | (inherits) | Writing production code is the core "daily driver" task |
| `data-engineer` | Sonnet | — | (inherits) | SQL/Cosmos/Databricks correctness matters, but is bounded in scope |
| `test-writer` | Sonnet | — | Read, Grep, Glob, Write, Edit, Bash | Good tests need judgment about edge cases, not just syntax |
| `code-reviewer` | Sonnet | — | Read, Grep, Glob, Bash | Everyday review catches real bugs without needing max reasoning |
| `architect` | **Opus** | high | Read, Grep, Glob, WebFetch, WebSearch, Write | Wrong architecture is expensive to reverse — worth paying for |
| `security-reviewer` | **Opus** | high | Read, Grep, Glob, Bash | A missed vulnerability costs far more than the token saving |

**Design choices worth knowing about:**

- **`architect` and `security-reviewer` never edit files.** They only read and write plan/
  report files. This is deliberate: keeping the most expensive model out of the
  edit-compile-fix loop (which is often iterative and token-heavy) and reserving it for the
  one-shot, high-leverage act of deciding or reviewing.
- **Every agent has a `maxTurns` cap.** This stops a stuck agent from silently burning
  tokens in a loop — it will stop and report rather than keep trying forever.
- **Return formats are constrained** ("under 30 lines", "`file:line`, not whole files").
  This matters as much as the model choice: an agent that dumps a full file back to the
  main session defeats the purpose, because the main session (often the more expensive
  model) then has to read all of it.
- **Agents are stack-agnostic where possible** (`implementer`, `test-writer`) and lean on
  the `stack-guides` skill for stack-specific conventions, rather than having 6 versions of
  `implementer`. This keeps the agent count manageable as you add stacks.

## 8. The 3 skills in depth

### `model-routing` — the rulebook that replaces a runtime router

This is a plain markdown file. Claude reads it (a few hundred tokens, no LLM call) before
deciding how to handle a multi-step task. It contains:

- A task-type → agent table (the core routing logic)
- An explicit "always Opus" list (security review of sensitive areas, hard-to-reverse
  architecture decisions) and an explicit "never Opus" list (formatting, renames, docs)
- An **escalation policy**: if Haiku fails once, retry with Sonnet; if Sonnet fails the same
  task twice, escalate to `architect` for a diagnosis rather than retrying blindly. This
  stops the "cheap model flails repeatedly" failure mode that can make Haiku *more*
  expensive than Sonnet on a task it wasn't suited for.
- A reminder about **not delegating small tasks at all** — every subagent invocation starts
  a fresh context and re-reads files, so a one-file, 20-line fix is often cheaper done
  directly by the main session than handed off.

### `handoff` — deliberate context resets

Long conversations are expensive because the entire history is re-sent with every new
message. This skill writes a short (`< 60 line`) `docs/ai/handoff.md` — goal, decisions,
key files, next step, open questions — so a developer can run `/clear` and resume with a
tiny context instead of an ever-growing one. This is the mechanism behind the "~20% from
habits" portion of the savings math in §5.

### `stack-guides` — correctness insurance for cheap models

This is arguably the most important skill for making Haiku/Sonnet delegation *safe*. A
cheap model given no guidance will happily produce code that looks right but violates a
team's conventions or, worse, a security practice (e.g., string-concatenated SQL, secrets
in `appsettings.json`, a Cosmos query with an unbounded partition scan). Each stack guide
has four short sections — **Conventions, Testing, Security, Cost & performance** — so an
agent reads only the ~300-token guide for its stack rather than needing a stronger, more
expensive model just to "know better."

Guides shipped: **`.NET`** (ASP.NET Core/C#/EF Core), **`Flutter`** (Dart), **`web`**
(React/Angular/TypeScript), **`Python`**, **`data`** (SQL/EF Core/Cosmos DB/Databricks/
PySpark), **`AI`** (Claude on Azure/Foundry, Azure OpenAI, RAG, agents — covering the OWASP
Top 10 for LLM applications).

## 9. Managed settings: how Claude Code picks which policy applies

Claude Code reads settings from several places, in a fixed precedence order (highest wins):

1. **Managed settings** — `managed-settings.json`, MDM, or the claude.ai admin console.
   Nothing a developer sets overrides this, with a small number of security-sensitive
   exceptions (e.g., a *stricter* local cap always wins).
2. Command line (`--settings`)
3. Project-local settings (`.claude/settings.local.json`)
4. Shared project settings (`.claude/settings.json`, committed to the repo)
5. User settings (`~/.claude/settings.json`)

**Within the managed tier**, by default only the *first* source that delivers a policy key
applies (not a merge): server-managed settings (claude.ai console) → MDM/OS policy → managed
settings file → the user-writable HKCU registry fallback (Windows only). This is why the
README's Step 3 says to pick **one** delivery mechanism — if you accidentally deliver the
policy two ways, only the higher-priority one is read for any key it sets.

**Where the file lives, per OS:**

| OS | Path |
|---|---|
| Windows | `C:\Program Files\ClaudeCode\managed-settings.json` (not the legacy `C:\ProgramData\...`, which Claude Code no longer reads) |
| macOS | `/Library/Application Support/ClaudeCode/managed-settings.json` |
| Linux/WSL | `/etc/claude-code/managed-settings.json` |

**Verifying it landed:** run `/status` inside Claude Code — the `Setting sources` line
names the source Claude Code selected (e.g., `Enterprise managed settings (file)`). If a
managed file isn't valid JSON, Claude Code refuses to start and names the broken file, so a
bad rollout fails loudly rather than silently.

**Model alias behavior relevant to this kit:**

| Alias | Resolves to (Anthropic API, at time of writing) |
|---|---|
| `opus` | Latest Opus |
| `sonnet` | Latest Sonnet |
| `haiku` | Latest Haiku |
| `opusplan` | Opus while in Plan Mode, Sonnet once execution starts |
| `default` | Depends on account type — check `/model` |

`availableModels: ["opus", "sonnet", "haiku"]` **restricts** which aliases a developer can
switch to with `/model`, `--model`, or their own settings files. It does *not* by itself
change the default the session starts with — that's the separate `model` key. Both are set
in the kit's policy file.

## 10. Measuring the real saving (OpenTelemetry)

The estimates in §5 are illustrative. To get real numbers for your organization, turn on
Claude Code's OpenTelemetry export (not included by default in this kit's policy — add it
when you're ready to measure):

```json
{
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://your-collector:4317"
  }
}
```

The metric `claude_code.cost.usage` (and `claude_code.token.usage`) carries attributes that
map directly onto this kit's design:

| Attribute | What it tells you |
|---|---|
| `model` | Split of spend across Haiku/Sonnet/Opus |
| `query_source` | `main` vs. `subagent` — shows how much work is actually being delegated |
| `agent.name` | Which of the 10 agents is doing the work, and how much |
| `type` | `input` / `output` / `cacheRead` — shows whether caching (via `handoff`) is helping |

**What to watch during a pilot:** the `query_source=main` share running on `model=opus`
should drop after rollout. If Haiku's `agent.name` share is climbing *and*
`claude_code.code_edit_tool.decision` (rejected/redone edits) is also climbing, Haiku is
being handed tasks it isn't suited for — see §11.

Full setup steps (collector, Prometheus, Grafana, dashboard queries) are covered separately;
ask if you want that written up as its own doc.

## 11. Risks and how the kit guards against them

| Risk | Guard in this kit |
|---|---|
| Haiku produces code that's subtly wrong | `implementer`/`test-writer`/`data-engineer` are Sonnet, not Haiku; Haiku is scoped to research/tests/docs only |
| Haiku flails and retries expensively | `maxTurns` cap per agent + the routing skill's escalation rule (fail once → move up a tier, don't retry the same tier) |
| A security issue slips through on a cheap model | `security-reviewer` is Opus with high effort, and the routing skill lists its trigger conditions explicitly (auth, payments, PII, secrets, crypto, uploads, LLM prompt handling, pre-release) |
| Architecture decisions get made cheaply and are expensive to reverse | `architect` is Opus with high effort and never edits code directly — only writes the plan |
| Developers ignore the new agents and just chat with the main session | Layer 1 (managed `opusplan` default) still saves money even if nobody ever invokes an agent by name |
| One team needs different models than the rest | Per-OS managed-settings deployment (Option B/C) lets you scope policy to a subset of machines; see §12 |
| A bad plugin update breaks 300 developers at once | Plugin version is pinned in `plugin.json`; `autoUpdate` rolls out in the background but you control what you push and when |

## 12. Tuning knobs, one by one

**"Haiku is giving weak results on code changes."**
Named agents (`implementer`, etc.) are unaffected by this — only *unnamed* subagents
default to Haiku via `CLAUDE_CODE_SUBAGENT_MODEL`. If general-purpose ad hoc subagent use is
the problem, raise that env var to `"sonnet"` in the policy.

**"A pilot group keeps overriding to Opus for everything."**
Set `availableModels` to `["sonnet", "haiku"]` for that group's policy file. Note this also
removes Opus from `opusplan`'s planning phase and from the `architect`/`security-reviewer`
agents for that group — only do this for a group that genuinely doesn't need those.

**"We want Fable for a small expert/research group."**
Fable is the most capable, most expensive tier. Give that group a separate managed-settings
file (Option B/C lets you target specific machines) that adds `"fable"` to `availableModels`.
Don't add it to the org-wide policy.

**"One team's agents need to behave differently."**
Copy the specific agent `.md` file into that repo's `.claude/agents/` with a new name (repo-
local agents take precedence for that project). Don't fork the whole plugin for one tweak.

**"We pushed a new/updated agent."**
Bump `version` in `plugins/cost-smart-dev/.claude-plugin/plugin.json`, push to the
marketplace repo. `autoUpdate: true` (set in the managed policy's `extraKnownMarketplaces`
entry) rolls it out to everyone in the background — no re-deployment of the settings file
needed.

**"We're on Azure / Microsoft Foundry, not the Anthropic API directly."**
The kit still works — the aliases (`opus`, `sonnet`, `haiku`) resolve to whatever your
Foundry deployment maps them to. If your deployments use custom names, set
`ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` /
`ANTHROPIC_DEFAULT_HAIKU_MODEL` in the policy's `env` block to point at your deployment
names.

## 13. FAQ

**Q: Doesn't handing work to more agents mean more total tokens?**
Often yes — see §4. More tokens is not the same as more cost. The kit optimizes for cost,
which is tokens × price-per-token, and most of the extra tokens land on the cheapest tier.

**Q: Why is `architect` Opus but capped so it never edits files?**
Because the expensive, hard-to-reverse part of `architect`'s job is the *decision*, not the
typing. Once a plan exists, `implementer` (Sonnet) can execute it far more cheaply than
having Opus stay in the loop through every edit-compile-fix cycle.

**Q: What if a task doesn't fit any of the 10 agents?**
The main session handles it directly, or uses the general-purpose subagent — which defaults
to Haiku via `CLAUDE_CODE_SUBAGENT_MODEL` for read-only work. The routing skill tells Claude
to explicitly pass `model: "sonnet"` when a general-purpose subagent needs to write code.

**Q: Does this require Claude Team or Enterprise?**
The managed-settings-file delivery (Option B/C in the README) works on any plan — it's an
OS-level file, not a claude.ai feature. The claude.ai admin console delivery (Option A) does
require Team or Enterprise with an Owner role.

**Q: How do we know the estimate holds for us?**
You don't, until you measure it — see §10 and Step 6 of the README. The 45–60% figure is a
starting expectation built from a general price ratio and a typical task mix, not a
guarantee for your specific codebases and workflows.
