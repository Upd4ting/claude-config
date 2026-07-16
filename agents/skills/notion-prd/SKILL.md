---
name: notion-prd
description: "Pipeline complet : brainstorming collaboratif d'une idée, création d'un plan d'implémentation détaillé avec vérification build/lint/test, et sauvegarde du plan dans la base Notion \"PRD\". Utiliser pour démarrer un nouveau feature ou projet, de l'idée au plan actionnable stocké dans Notion."
---

# Notion PRD Pipeline

## Overview

Unified pipeline: brainstorm an idea → write a detailed implementation plan → save it to Notion.

Three phases, executed sequentially:

1. **Brainstorming** — Collaborative design exploration (from @brainstorming)
2. **Implementation Plan** — Detailed plan with mandatory build/lint/test verification (modified @writing-plans)
3. **Notion Save** — Push the plan to the "PRD" database in Notion (using @notion)

> **Important:** This skill produces and **stores** the plan on Notion — it does NOT execute it. After the Notion page is created, stop.

---

## Phase 1 — Brainstorming

Follow the @brainstorming process exactly:

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits)
- Ask questions one at a time to refine the idea
- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message - if a topic needs more exploration, break it into multiple questions
- Focus on understanding: purpose, constraints, success criteria

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs
- Present options conversationally with your recommendation and reasoning
- Lead with your recommended option and explain why

**Presenting the design:**

- Once you believe you understand what you're building, present the design
- Break it into sections of 200-300 words
- Ask after each section whether it looks right so far
- Cover: architecture, components, data flow, error handling, testing
- Be ready to go back and clarify if something doesn't make sense

**Key principles:**

- One question at a time
- Multiple choice preferred
- YAGNI ruthlessly
- Explore alternatives — always propose 2-3 approaches before settling
- Incremental validation — present design in sections, validate each

### Transition to Phase 2

Once the design is complete and validated, ask: "Ready to set up the implementation plan?"

When user confirms → **continue directly to Phase 2 below**. Do NOT invoke `writing-plans` as a sub-skill.

---

## Phase 2 — Implementation Plan

Write a comprehensive implementation plan. Assume the executing engineer has zero context for the codebase.

### Pre-plan questions

Ask these questions before writing the plan:

**1. Starting branch:**

"Which branch should we start from? (e.g., `main`, `develop`, a specific branch)"

**2. Development mode:**

"Which development approach do you prefer?

- **TDD** - Test first, then implementation (red-green-refactor cycle)
- **Non-TDD** - Direct implementation without tests"

If Non-TDD selected, also ask:

"How should work be verified for each task?

- Manual testing (describe what to check)
- Run a command (e.g., `pnpm run build`, `pnpm run lint`)
- Visual inspection
- Other (describe)"

**3. Commit strategy:**

"Should commits be included in the plan?

- **Yes** - Include commit step after each task (recommended for tracking progress)
- **No** - No commit steps (useful when experimenting or for a single final commit)"

### Detect verification commands

Before writing the plan, detect the project's verification commands by checking:

- `package.json` → scripts (build, lint, test, typecheck)
- `Makefile` → targets
- `Cargo.toml` → cargo build/test/clippy
- `pyproject.toml` → configured tools
- Other project config files

**Build, lint, and test commands are mandatory in the plan.** Every task must include a verification step that runs these commands. If a project doesn't have one of them, note it but include the ones that exist.

### Plan document header

Every plan MUST start with this header:

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Starting Branch:** [Branch name]

**Mode:** TDD / Non-TDD

**Commits:** Yes / No

**Verification Commands:**
- Build: `[command]`
- Lint: `[command]`
- Test: `[command]`

**Verification Method (Non-TDD only):** [How to verify each task - command, manual steps, etc.]

---
```

### Task structure

#### Template TDD

````markdown
### Task N: [Component Name]

**Files:**

- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts:123-145`
- Test: `tests/exact/path/to/file.spec.ts`

**Step 1: Write the failing test**

```typescript
describe('specificBehavior', () => {
  it('should return expected result', () => {
    const result = myFunction(input);
    expect(result).toBe(expected);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm run test tests/path/file.spec.ts`
Expected: FAIL with "myFunction is not defined"

**Step 3: Write minimal implementation**

```typescript
export function myFunction(input: string): string {
  return expected;
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm run test tests/path/file.spec.ts`
Expected: PASS

**Step 5: Verify build/lint**

Run: `[build command] && [lint command]`
Expected: No errors

**Step 6: Commit** _(if Commits = Yes)_

Use @committing skill
````

#### Template Non-TDD

````markdown
### Task N: [Component Name]

**Files:**

- Create: `exact/path/to/file.ts`
- Modify: `exact/path/to/existing.ts:123-145`

**Step 1: Implement the functionality**

```typescript
export function myFunction(input: string): string {
  return expected;
}
```

**Step 2: Verify build/lint/test**

Run: `[build command] && [lint command] && [test command]`
Expected: All pass with no errors

**Step 3: Verify** _(additional verification if specified)_

Run: [Verification method from plan header]
Expected: [Expected result]

**Step 4: Commit** _(if Commits = Yes)_

Use @committing skill
````

### Plan principles

- Exact file paths always
- Complete code in plan (not "add validation")
- Exact commands with expected output
- Reference relevant skills with @ syntax
- DRY, YAGNI, verification before commit
- If Commits = Yes: frequent commits after each task
- Reference @committing for commits
- Reference @executing-plans and @subagent-driven-development for execution

### Save the plan

Save the plan to `PLAN.md` at the project root. Then proceed directly to Phase 3.

---

## Phase 3 — Save to Notion

### Setup

Read the Notion API key:

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
```

If the file doesn't exist, refer to @notion for setup instructions and ask the user to configure it before continuing.

### Find the PRD database

Search for the "PRD" database:

```bash
curl -s -X POST "https://api.notion.com/v1/search" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{"query": "PRD", "filter": {"value": "database", "property": "object"}}'
```

Extract the `id` from the matching database result.

### Get repository URL

```bash
git remote get-url origin
```

### Create the page

Create a page in the PRD database with **only** these properties:

- **Nom** (title): Clear, descriptive name in English for the feature/project
- **Status** (status): `"Pas commencé"`
- **Repo** (url): Repository URL from git remote

**Do NOT fill any other database field** (Branch, PR URL, StartedAt, FinishedAt, RunLog, etc.). These are managed separately during execution.

```bash
curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": {"database_id": "DATABASE_ID"},
    "properties": {
      "Nom": {"title": [{"text": {"content": "Feature Name"}}]},
      "Status": {"status": {"name": "Pas commencé"}},
      "repo": {"url": "REPO_URL"}
    }
  }'
```

### Add plan content as blocks

Convert the plan markdown into Notion blocks and append them to the page. Use appropriate block types:

- `heading_2` / `heading_3` for headers
- `paragraph` for text
- `code` for code blocks (with language)
- `bulleted_list_item` for bullet lists
- `numbered_list_item` for numbered lists

**API limits:**

- Maximum **100 blocks per request** — split into multiple requests if needed
- Maximum **2000 characters per rich_text element** — split long text across multiple rich_text elements within the same block

```bash
curl -s -X PATCH "https://api.notion.com/v1/blocks/PAGE_ID/children" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "children": [
      {"object": "block", "type": "heading_2", "heading_2": {"rich_text": [{"text": {"content": "Section Title"}}]}},
      {"object": "block", "type": "paragraph", "paragraph": {"rich_text": [{"text": {"content": "Content here"}}]}}
    ]
  }'
```

### Completion

After successfully creating the Notion page:

1. Display the URL of the created page
2. Delete PLAN.md file
3. **Stop here.** Do NOT proceed to execute the plan.