# Ano Skills

Claude Code skills for [Ano](https://ano.chat).

Ano is team chat with Claude Code and agents built in. These skills teach Claude Code how to work with Ano: use the `ano` CLI, read workspace context, send messages, and understand payloads sent from the Ano desktop app.

## Install

```bash
claude plugin install @ano-chat/skills
```

## What Is Included

- `ano-cli`: how Claude Code uses the [`ano` CLI](https://www.npmjs.com/package/@ano-chat/cli)
- `ano-payloads`: how Claude Code reads `<ano_payload>` blocks from the Ano desktop app

## Use It

Install the Ano CLI. Two paths — pick whichever fits your setup:

```bash
# Native binary (recommended — ~20ms cold start, no Node required)
curl -fsSL https://raw.githubusercontent.com/ano-chat/ano-cli/main/scripts/install.sh | bash

# npm (works everywhere Node 20+ runs, including Windows)
npm install -g @ano-chat/cli
```

Sign in:

```bash
ano auth login
```

Then ask Claude Code to work with Ano, for example:

```text
Read the latest messages in #general.
Send a DM to Jane.
Search Ano for the staging error thread.
```

## Links

- Website: [ano.chat](https://ano.chat)
- CLI package: [`@ano-chat/cli`](https://www.npmjs.com/package/@ano-chat/cli)
- Skills package: [`@ano-chat/skills`](https://www.npmjs.com/package/@ano-chat/skills)
