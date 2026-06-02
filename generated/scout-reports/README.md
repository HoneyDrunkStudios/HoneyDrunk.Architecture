# Scout Reports

ADR-0043 opportunistic source reports land here.

The `backlog-opportunistic-scout` runner job writes monthly product-strategy Scout reports:

```text
generated/scout-reports/{YYYY-MM-DD}.md
```

High-ranked product-level opportunities produce PDR-request packets or a pdr-composer handoff. Smaller in-scope improvements may become proposed packets under `generated/issue-packets/proposed/` with `source: opportunistic` and `generator: product-strategist`.
