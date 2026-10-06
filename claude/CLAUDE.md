# Langue

- Réponds toujours en français dans la conversation.
- En revanche, tout ce qui est artefact technique reste TOUJOURS en anglais : code, commentaires de code, messages de commit, noms de branches, titres et descriptions de PR, documentation dans les repos.

## Git commits and pull requests

Never include Claude session URLs in git commit messages or pull request descriptions.
Never include `Claude-Session:` trailers.
Never include Claude Code attribution, Generated-with footers, or Co-Authored-By trailers.
Commit messages and pull request titles follow Conventional Commits: `<type>(<optional scope>): <summary>`, with type one of `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`.
Branch names are `<type>/<short-kebab-case-slug>` with the same types, e.g. `feat/notion-review-skill`.
In cloud sessions the assigned branch has an auto-generated name. You may create a conventionally named branch instead, push to it, and open the pull request from it.
