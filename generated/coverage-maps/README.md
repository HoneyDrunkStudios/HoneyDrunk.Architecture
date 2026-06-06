# `generated/coverage-maps/`

Decision-to-implementation traceability maps.

Use this surface when an accepted ADR/PDR is broad enough that backlog-generation cannot safely infer missing work from packet metadata alone. A coverage map records which commitments are already covered by downstream ADRs, packets, or initiative entries; which commitments are deliberately deferred; and which commitments need new proposed packets.

Coverage maps are generated artifacts. They do not move packets from `proposed/` to `active/`, flip decision status, or directly implement runtime behavior.
