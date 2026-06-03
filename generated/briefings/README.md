# Backlog Briefings

ADR-0043 weekly briefing outputs land here.

The `backlog-weekly-briefing` runner job writes:

```text
generated/briefings/{YYYY-MM-DD}.md
```

Each briefing summarizes new proposed packets, recently completed active packets, stale active work, stale proposed work, urgent reactive packets, and the top three recommended actions for the week.

`urgent.md` is a rolling durable surface for `priority: urgent` reactive packets that should not wait for the weekly briefing.
