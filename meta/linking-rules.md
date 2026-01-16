# MissionControl Linking Rules

## Internal Links

Use relative paths from document location:

```markdown
<!-- From /repos/credentialmate/kb/auth.md -->
See [global auth patterns](../../../kb/authentication.md)
See [related decision](../../../ris/decisions/credentialmate-042-api-versioning.md)
```

## Cross-Repo References

When referencing content in source repositories (not yet migrated):

```markdown
<!-- External reference format -->
[Auth implementation](repo:credentialmate/apps/backend-api/src/contexts/auth/)
```

Use `repo:` prefix to indicate external repository reference.

## Link Validation Rules

| Rule | Enforcement |
|------|-------------|
| No broken internal links | BLOCKING |
| External repo refs must use `repo:` prefix | BLOCKING |
| No absolute filesystem paths | BLOCKING |
| No URLs to local services | BLOCKING |

## Prohibited Patterns

```markdown
<!-- NEVER use these -->
[file](/Users/tmac/1_REPOS/...)           <!-- Absolute path -->
[api](http://localhost:8000/...)          <!-- Local URL -->
[doc](../../other-repo/docs/...)          <!-- Cross-repo relative -->
```

## Migration Link Handling

During migration:
1. External links become internal links
2. `repo:` prefix removed when content migrates
3. Redirects documented in `/meta/link-redirects.md` (if needed)

## Orphan Detection

Documents with no inbound links after 90 days flagged for review.
Documents with only outbound links require justification.
