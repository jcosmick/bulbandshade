# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

This is a **single-context** repo. (`docs/` is the GitHub Pages site, so agent docs live under `agent_docs/` instead.)

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root.
- **`agent_docs/adr/`**: read ADRs that touch the area you're about to work in.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved. When it does, ADRs go in `agent_docs/adr/`, not `docs/adr/`.

## File structure

```
/
├── GLOSSARY.md
├── agent_docs/
│   ├── agents/          ← skill configuration (this file)
│   └── adr/
│       ├── 0001-some-decision.md
│       └── 0002-another-decision.md
├── levels/
├── scenes/
└── scripts/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (some decision), but worth reopening because…_
