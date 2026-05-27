---
name: ano-tables
description: |
  Read and write Ano tables (structured rows / lists / databases) via the
  `ano` CLI — list tables, fetch schema, query with filters/sorts, create
  tables, create/update/archive items, comment on items. Self-contained.
triggers:
  - list tables
  - show tables
  - query table
  - read table
  - create table
  - add row
  - add table item
  - update row
  - update table item
  - comment on table item
invocable: true
argument-hint: "[command] [args...]"
---

# Ano CLI — Tables

## Essentials

- Output: `--agent` for raw JSON, `--json` for envelope. Never parse styled TTY.
- Exit codes: 0 OK · 1 USAGE · 2 NOT_FOUND · 3 AUTH · 4 FORBIDDEN · 5 RATE_LIMIT.
- On exit 3 (AUTH), orchestrate the triggered-auth flow inline.
- **Fetch a table's schema BEFORE writing.** `ano tables get <id> --agent` returns the field-definition IDs. `create-item` / `update-item` require `--fields` JSON **keyed by field-definition ID**, NOT by the human-readable field name. Skipping this returns exit 2.

## Decision tree

```
Need structured data (lists, databases, rows)?
├── What tables exist?   → ano tables list --agent
├── Schema + field IDs?  → ano tables get <table-id> --agent
├── Read rows?           → ano tables query <table-id> --agent
├── Filter rows?         → ano tables query <table-id> --filter '[{"field_id":"f1","operator":"eq","value":"done"}]' --agent
├── Add a row?           → ano tables get <table-id> --agent       (FIRST — learn field IDs)
│                        → ano tables create-item --table <table-id> --fields '{"<field_id>":"..."}' --agent
├── Edit a row?          → ano tables update-item <item-id> --fields '{"<field_id>":"..."}' --agent
├── Archive a row?       → ano tables update-item <item-id> --archive --agent
└── Comment on a row?    → ano tables comment <item-id> "body text" --agent
```

## Quick reference

| Task               | Command                                                               |
| ------------------ | --------------------------------------------------------------------- |
| List tables        | `ano tables list --agent`                                             |
| Get table + schema | `ano tables get <table-id> --agent`                                   |
| Query items        | `ano tables query <table-id> --agent`                                 |
| Query (filtered)   | `ano tables query <table-id> --filter '<json-array>' --agent`         |
| Query (sorted)     | `ano tables query <table-id> --sort '<json>' --agent`                 |
| Create table       | `ano tables create "<name>" --agent`                                  |
| Create item        | `ano tables create-item --table <table-id> --fields '<json>' --agent` |
| Update item        | `ano tables update-item <item-id> --fields '<json>' --agent`          |
| Archive item       | `ano tables update-item <item-id> --archive --agent`                  |
| Comment on item    | `ano tables comment <item-id> "body" --agent`                         |

## Workflows

### Add a row (schema-first pattern)

```bash
# 1. Discover field IDs
ano tables get tbl_abc --agent
# → { "fields": [{"id":"fld_title","name":"Title", "type":"text"}, ...] }

# 2. Compose --fields keyed by field-definition ID
ano tables create-item --table tbl_abc \
  --fields '{"fld_title":"Q3 launch","fld_owner":"usr_xyz","fld_status":"in_progress"}' \
  --agent
```

### Filter + sort a query

```bash
ano tables query tbl_abc \
  --filter '[{"field_id":"fld_status","operator":"eq","value":"in_progress"}]' \
  --sort '{"field_id":"fld_updated_at","direction":"desc"}' \
  --agent
```

### Archive vs delete

```bash
# Soft archive — reversible by `update-item --restore`.
ano tables update-item itm_123 --archive --agent
```

## Edge cases

- **Field IDs only**: human-readable field names will return exit 2 (NOT_FOUND). Always fetch schema first.
- **Filter operators**: `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `contains`, `starts_with`, `is_null`, `is_not_null`. Operator availability depends on the field type — see `ano tables get` output.
- **Sort direction**: `asc` or `desc`. Multi-sort = an array of `{field_id, direction}` objects.
- **`--archive`** is a soft delete. The row stays in the DB; it just disappears from default queries. Restore with `update-item --restore`.
