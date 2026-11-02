# Plan: clamp the counter at zero

The `floor` vector expects a decrement at zero to stay at zero; today it goes to -1.

1. In `Counter.reduce`, make `.decrement` clamp at zero, mirroring how `.increment` clamps at `limit`.
2. No new vectors: `floor/stops-at-zero` already covers it.
