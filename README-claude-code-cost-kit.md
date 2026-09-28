# Claude Code Cost Kit

Makes Claude Code use the **cheapest model that can do each task well**, across every
developer and every project, with nothing for anyone to remember.

**Expected saving vs. "everyone defaults to Opus": ~45–60%.** This is an estimate — see
[DETAILS.md](DETAILS.md) for the full math and how to confirm your real number with a pilot.

📖 **Read this file to install it.** For *why* it's built this way, the cost math, and a
file-by-file explanation, see **[DETAILS.md](DETAILS.md)**.

---

## What you get

- **A company policy** (`01-managed-settings/`) that IT deploys once to every machine.
  Sets the default model to `opusplan` (cheap-by-default), locks out the most expensive
  model tier, and force-installs the plugin below.
- **A plugin** (`02-marketplace/`) with **10 specialist agents**, each permanently tied to
  the right model (Haiku, Sonnet or Opus), plus **3 skills**: a routing rulebook, a
  context-handoff helper, and coding/security guides for your stacks (.NET, Flutter,
  React/Angular/TypeScript, Python, data, AI).
- **Project templates** (`03-project-templates/`) — a short `CLAUDE.md` and a one-page
  habits sheet for developers.

| Agent | Model | Used for |
|---|---|---|
| `researcher` | Haiku | Finding code, reading many files, summarizing docs |
| `test-runner` | Haiku | Running build/tests/lint, reading long logs |
| `doc-writer` | Haiku | READMEs, doc comments, changelogs, PR descriptions |
| `designer` | Sonnet | API contracts, entity shapes, screen/component structure |
| `implementer` | Sonnet | Writing and changing code in any stack |
| `data-engineer` | Sonnet | SQL, EF Core, Cosmos DB, Databricks, PySpark |
| `test-writer` | Sonnet | Unit, widget, integration and API tests |
| `code-reviewer` | Sonnet | Everyday diff review |
| `architect` | Opus (high effort) | Plans for big features, hard decisions, stuck bugs |
| `security-reviewer` | Opus (high effort) | Auth, payments, personal data, secrets, LLM prompts, pre-release |

---

## Quick start (5 commands, on your own machine)

Try it before deploying it anywhere:

```bash
claude plugin validate ./02-marketplace
claude plugin marketplace add ./02-marketplace
claude plugin install cost-smart-dev@yourorg-claude-tools
claude plugin details cost-smart-dev
```

The last command should print `Skills (3)` and `Agents (10)`. Inside a Claude Code session,
type `@agent-cost-smart-dev:` and the 10 agents will appear in the suggestions.

> The old `/agents` wizard has been removed from Claude Code — don't use it to check this;
> use `claude plugin details` or the `@agent-` suggestion list instead.

---

## Full rollout, step by step

### Step 1 — Host the marketplace (15 min)

1. Create an empty git repo, e.g. `claude-marketplace` (GitHub or Azure DevOps).
2. Push the **contents** of `02-marketplace/` to it, so `.claude-plugin/` sits at the repo
   root.
3. Give every developer **read access**. Claude Code clones it with each developer's own
   git credentials.

### Step 2 — Point the policy at your marketplace (5 min)

Open `01-managed-settings/managed-settings.json` (or the `.github-variant.json` if you
host on GitHub) and replace the placeholder org/project/repo names with yours.

> If you rename the marketplace from `yourorg-claude-tools`, change it in **three** places:
> `marketplace.json`'s `name`, the `extraKnownMarketplaces` key, and the
> `@yourorg-claude-tools` suffix in `enabledPlugins`.

### Step 3 — Deploy the policy (pick one)

Only **one** managed-settings source applies per machine by default, so pick one:

| Option | Best for | What it does |
|---|---|---|
| **A. claude.ai admin console** | Claude Team/Enterprise, no MDM | An Owner pastes the JSON at **Organization settings → Claude Code → Managed settings**. Applies org-wide, no scripts. |
| **B. Windows (Intune/GPO)** | Windows fleets | Run `01-managed-settings/windows/Deploy-ClaudeCodePolicy.ps1` as SYSTEM. Writes `C:\Program Files\ClaudeCode\managed-settings.json`. |
| **C. macOS (Jamf/Kandji)** | Mac fleets | Run `01-managed-settings/macos/deploy-claude-policy.sh` as root. Writes `/Library/Application Support/ClaudeCode/managed-settings.json`. |

Use B/C instead of A if you want different settings for different teams — the console
applies one policy to everyone.

### Step 4 — Verify on one machine

Inside Claude Code:

```
/status     →  "Setting sources" line shows "Enterprise managed settings (...)"
/model      →  default is opusplan; only opus/sonnet/haiku selectable
/plugin     →  cost-smart-dev is installed and enabled
```

In a terminal: `claude plugin details cost-smart-dev` → `Agents (10)`, `Skills (3)`.

If the policy JSON is broken, Claude Code refuses to start and names the file —
`claude doctor` shows exactly what was dropped.

### Step 5 — Roll out to projects and people

1. Drop `03-project-templates/CLAUDE.md.template` into each repo (fill in the blanks,
   keep it short — it's loaded on every single turn).
2. Decide whether `docs/ai/` (plans + handoffs) is committed or gitignored.
3. Share `03-project-templates/DEVELOPER-HABITS.md` in onboarding and team channels.

### Step 6 — Pilot before rolling out to everyone (2–3 weeks)

1. Deploy to 20–30 developers first (Options B/C make this easy to scope); leave a similar
   group unchanged as a comparison.
2. Compare **cost**, not token counts (see [DETAILS.md §4](DETAILS.md#4-tokens-vs-cost--the-distinction-that-matters)
   for why they're different) — from your usage/billing reports.
3. Track quality too: reopened bugs, rejected PRs, developer feedback on weak answers.
4. For a precise before/after split by model and by agent, turn on OpenTelemetry — see
   [DETAILS.md §10](DETAILS.md#10-measuring-the-real-saving-opentelemetry).

---

## Common adjustments

| If you see… | Do this |
|---|---|
| Unnamed helper subagents giving weak results | Set `CLAUDE_CODE_SUBAGENT_MODEL` to `sonnet` in the policy (the 10 named agents are unaffected — they already have a fixed model) |
| A group keeps switching everything to Opus | For that group's policy, set `availableModels` to `["sonnet","haiku"]` — note this also disables `opusplan`'s Opus planning phase for them |
| Want Fable for a small expert group | Add `"fable"` to `availableModels` in a separate policy scoped to just that group |
| One repo needs a tweaked agent | Copy that agent's `.md` into the repo's own `.claude/agents/` under a new name |
| You update an agent or skill | Bump `version` in `plugin.json`, push — `autoUpdate: true` rolls it out in the background |

**On Azure / Microsoft Foundry?** The kit still works — see
[DETAILS.md §12](DETAILS.md#12-tuning-knobs-one-by-one) for mapping custom deployment names.

---

## Why not a runtime "router" subagent?

A subagent can't change the main session's own model, and the main session accounts for
60–80% of tokens in a typical workflow. A router subagent also adds its own LLM call and
cold start to every task. This kit's policy-default + fixed-model-agents + routing-rulebook
approach reaches the same routing decisions for close to zero runtime overhead — full
reasoning in [DETAILS.md §2](DETAILS.md#2-why-not-a-runtime-router-subagent).

---

## Repository layout

```
claude-code-cost-kit/
├── README.md                    You are here
├── DETAILS.md                   Full explanation, cost math, file-by-file reference
├── 01-managed-settings/         Company policy — IT deploys once
├── 02-marketplace/              The plugin — push as its own git repo
└── 03-project-templates/        Copy into each project repo
```
