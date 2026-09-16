---
name: codex-handoff
description: Hand the current Codex task off to a fresh task or background agent that picks up the work immediately. Use when the user explicitly asks to hand off, fork, or continue the work elsewhere.
---

Write a compact handoff summary of the current task so another Codex task or agent can continue the work. When Codex thread tools are available and the user explicitly requested a new task, create it with the native thread-creation tool and seed it with the summary. For an internal bounded subtask, use the native subagent tool instead. If neither capability is available, save the summary as a Markdown handoff file and return its path.

Use a short descriptive task name such as `Fix login bug`.

Include a "suggested skills" section in the summary, naming relevant skills with Codex's `$skill-name` syntax.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information, since the summary becomes the agent's prompt.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the summary accordingly.
