# AI / LLM features (Claude on Azure / Microsoft Foundry, Azure OpenAI, RAG, agents)

## Conventions
- Call models from the backend only, never directly from mobile or browser code.
- Keep model IDs, endpoints and deployment names in configuration, not code, so they can change per environment and provider.
- Put prompts in versioned files/templates, not inline strings scattered through the code.
- Ask for structured output (JSON schema / tool use) when code consumes the result; validate it before use.
- Set timeouts, retries with backoff for 429/5xx, and a max output token limit on every call.
- Log token usage and latency per call (without logging user content unless approved).

## Picking the model in your product (same idea as for Claude Code)
- Cheapest model that passes your evals: Haiku-class for classification, extraction, routing and short summaries; Sonnet-class for most generation and tool use; Opus-class only for the hardest reasoning.
- Use prompt caching for large, repeated system prompts or documents.
- Build a small eval set (20–50 real examples) before switching models or changing prompts.

## Testing
- Unit-test prompt building and output parsing with recorded/fake responses; no live model calls in unit tests.
- Separate, opt-in eval runs against real models with a spend cap.

## Security (OWASP Top 10 for LLM applications)
- Treat model output as untrusted: never pass it straight into SQL, shell, HTML or `eval`.
- Prompt injection: content from users, documents or the web can contain instructions. Keep system instructions separate, restrict tools, and require confirmation for high-impact actions.
- Tools/agents get least privilege: read-only by default, scoped credentials, allow-lists for URLs and actions.
- No secrets or unnecessary PII in prompts; respect data residency and your Azure data-handling settings.
- RAG: enforce the user's document permissions at retrieval time, not after generation.
- Rate-limit and cap spend per user/tenant.

## Cost & performance
- Trim context: retrieve only the top relevant chunks; summarize long histories.
- Stream responses for UX; batch offline workloads where the provider supports batch pricing.
