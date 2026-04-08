# HoneyDrunk.Lore — Invariants

Lore-specific invariants (supplements `constitution/invariants.md`).

1. **Raw sources are never modified.**
   Files in `raw/` are ingested as-is. The LLM compiles from them but never edits originals.

2. **Wiki articles cite their sources.**
   Every compiled article in `wiki/` links back to the raw sources it was derived from.

3. **Indexes are auto-maintained.**
   The LLM maintains index files, backlinks, and summaries. Manual index edits are overwritten on next compilation pass.

4. **Query outputs are filed with provenance.**
   When an output is filed back into the wiki, it includes metadata about the query that generated it.

5. **Health checks are non-destructive.**
   Linting passes identify issues and suggest fixes. They do not auto-apply changes without an explicit compilation pass.

6. **The wiki is the LLM's domain.**
   Humans browse and query the wiki. The LLM writes and maintains it. Human edits to `wiki/` may be overwritten.
