# HIG Phase 1 — Roadmap (execution engine only)

This roadmap implements the **automated execution engine** described in `concept.md`: single chart symbol, single timeframe, new-bar signal evaluation, market entries with SL/TP, basic risk gates, logging, and restart-safe state. Strategy validation and test passes are **out of band** (you run them); the roadmap only requires a **clean compile** at each weekly checkpoint before you test.

---

## Phase 1 outcome (done when)

- EA compiles and runs on the chart symbol: reads indicators, evaluates the Phase 1 signal, applies risk checks, sends **market** orders with SL/TP (including RR-based TP), respects spread/slippage/max trades/cooldown/permissions, and recovers internal state after restart using terminal data + `OnTradeTransaction`.
- **One entry per signal** (first grid leg only); no laddering, no pendings, no partial closes.
- No multi-symbol scan, no portfolio layer, no AI/session calendar filters, no full volume-profile engine.

---

## In scope vs out of scope (guardrails)

| In scope (Phase 1) | Out of scope (do not build now) |
|--------------------|----------------------------------|
| Modular `.mqh` files: signal, risk, execution, logging, thin state | Generic plugin system, scriptable signals, DLLs |
| `iATR`, custom VWAP via `iCustom` + documented `.ex5` | Full institutional VP, rolling VWAP |
| VP **proxy** (e.g. VWAP deviation bands you already chose) | Third-party VP stacks, many tunable bands |
| Prior session high/low (simple time math) | Asian/London/NY **trading windows** as filters |
| `CTrade` (or one thin wrapper), validation, magic, comments | Multi-strategy router, correlation |
| `OnTradeTransaction` + `OnInit` rescan for this symbol/magic | Cross-chart sync, global position hub |
| Grouped `input` parameters per `concept.md` | Large optimization surface, micro-parameters |

If a task is not required to place a **correctly sized, validated market order** on a valid signal, defer it.

---

## Compile once before testing (weekly rule)

**Rule:** During the week you can edit freely, but **before each test session** you integrate everything for that week into the EA, fix includes, then run **one** MetaEditor compile on `HIG.mq5`. If it fails, fix until green—then test. Avoid leaving the repo mid-week with broken includes or missing `iCustom` paths.

**Practical habit:** End each week with a tagged mental checkpoint: “Week N complete = project compiles + EA loads on chart without init failure.”

---

## Suggested folder layout (minimal)

Keep the expert in `Experts\HIG\` and shared headers under the terminal’s Include tree (MetaEditor resolves `Experts` and `Include`):

```text
MQL5\Experts\HIG\
  HIG.mq5
  HIG_*.mqh           // headers live next to the EA (#include "…")
  concept.md
  roadmap.md
  HIG.mqproj
```

If you prefer fewer files initially, merge `HIG_State.mqh` into `HIG_Risk.mqh`—do **not** add more layers until one file is uncomfortable to navigate.

---

## Weekly implementation plan

### Week 1 — Scaffolding and compile baseline

**Deliverables**

- Create `Include\HIG\` and stub `.mqh` files with empty or minimal functions (`bool HIG_Signal_Init()`, `void HIG_Signal_OnDeinit()`, `void HIG_Signal_OnNewBar()` placeholders, etc.).
- `HIG.mq5`: `OnInit` / `OnDeinit` / `OnTick` wired; **new bar detection** only (compare `iTime(_Symbol, PERIOD_CURRENT, 0)` to static/struct field).
- `HIG_Log.mqh`: optional debug flag + one function to print structured lines (no per-tick spam by default).
- `#property strict` / version header as you prefer; magic number input.

**Explicitly not this week**

- Real indicators, orders, risk maths.

**Checkpoint**

- Single compile: EA loads, attaches, `OnInit` succeeds, optional log on first new bar.

---

### Week 2 — Inputs and indicators (still no live trading)

**Deliverables**

- All **grouped inputs** from `concept.md` (signal, VWAP, ATR, risk, execution, permissions, debug)—defaults sensible, small count.
- `HIG_Indicators.mqh`: create in `OnInit` — `iATR`, `iCustom` for VWAP (path + inputs documented in comments or `concept.md`), any handle for VP **proxy** if separate; prior-session H/L via rates (`CopyTime` / `CopyHigh` / `CopyLow` for D1 or broker “day” alignment per your VWAP choice).
- `OnDeinit`: release all handles.
- On each **new bar**, copy buffers needed for the **last closed** bar (index `1`) into structs or locals; log **one line** if debug on (e.g. VWAP + ATR read OK).

**Explicitly not this week**

- `OrderSend`, `OnTradeTransaction`, recovery logic beyond “handles valid”.

**Checkpoint**

- Single compile: init succeeds on symbols where VWAP `.ex5` exists; fail fast with clear `Print` if `iCustom` invalid (acceptable for your test setup).

---

### Week 3 — Signal engine only (no orders)

**Deliverables**

- Implement long/short rules from `concept.md`: VWAP side, value proxy band, ATR distance, candle confirmation, invalidation list—all evaluated on **closed bar** data only.
- Output: enumerated signal (`None` / `Long` / `Short`) + optional log codes (`SIGNAL_LONG_VALID`, etc.).
- Wire **trade permissions** (buy only / sell only / both) at signal output (mask direction only; still no send).

**Explicitly not this week**

- Lot calculation, SL/TP placement, `CTrade`.

**Checkpoint**

- Single compile: Visual Mode or live chart shows coherent logs when signals flip; no trading.

---

### Week 4 — Risk + execution (first real orders)

**Deliverables**

- `HIG_Risk.mqh`: max spread, slippage, equity/balance floor, max simultaneous positions **for this EA magic + symbol**, cooldown since last **successful** trade, ATR cap if specified, volume normalize, min/max lot, stops/freeze distance checks.
- Position sizing: fixed lot and/or percent-risk to lot (whichever you committed to first; second can follow in same week if small).
- `HIG_Execution.mqh`: market buy/sell with SL/TP — SL from fixed points or ATR multiple; TP from `SL distance × RR` per `concept.md`. Netting vs hedging: respect `ACCOUNT_MARGIN_MODE`; reverse direction policy as per spec (netting closes or reduces before flip—implement the simplest correct behaviour for your broker test account first).
- Duplicate-send guard: e.g. do not re-send on the same signal bar without fill/transaction handling (minimal flag + bar id).

**Explicitly not this week**

- Full `OnTradeTransaction` state machine polish (Week 5); this week can use send result + basic flag.

**Checkpoint**

- Single compile: demo/small risk — one entry per valid signal path; SL/TP visible on terminal.

---

### Week 5 — Lifecycle, recovery, and Phase 1 closure

**Deliverables**

- `OnTradeTransaction`: update “our” position count, last trade time, clear pending-send state; confirm magic ownership.
- `OnInit` (and optionally first tick): rescan positions/orders for `_Symbol` + magic; rebuild cooldown and open-trade counts from live data.
- Cooldown / max trades / spread blocks: log with stable codes (`BLOCK_*`) per `concept.md`.
- Remove dead code, align names with spec, ensure **no per-tick logging** unless verbose debug.

**Explicitly not this week**

- Grid laddering, pendings, partials, multi-symbol, session calendar filters, optimisation harness.

**Checkpoint**

- Single compile: restart terminal or reattach EA—counts and cooldown behaviour match expectations; then you own full tester/demo checklist from `concept.md`.

---

## Definition of Done (Phase 1 engine)

- [ ] Spec in `concept.md` matches behaviour (single symbol, first leg only, market orders, RR TP, no partials).
- [ ] Weekly compile rule satisfied at Weeks 1–5 checkpoints.
- [ ] No discretionary session **filters**; VWAP day anchor and prior session levels only as defined.
- [ ] Hedging vs netting handled without undefined states for reverse signals.
- [ ] Logs sufficient for your testing workflow without tick spam.

---

## After Phase 1 (do not start until engine is stable)

- Grid laddering, pendings, trade manager “scaling”, richer VP, session **windows** as filters, multi-symbol—pick **one** extension at a time after review.

---

## Implementation checklist (sub-todos — Weeks 1–5)

Use MetaEditor: compile `Experts\HIG\HIG.mq5` once per checkpoint. Put headers in `MQL5\Include\HIG\`. Install a VWAP `.ex5` whose name matches `InpVWAP_Indicator` (buffer `InpVWAP_Buffer` = VWAP line per bar).

### Week 1 — Scaffold

- [x] `Include\HIG\` headers created and included from `HIG.mq5`
- [x] New-bar gate using `iTime(_Symbol, PERIOD_CURRENT, 0)`
- [x] `HIG_Log_Line` + grouped inputs in `HIG_Config.mqh`
- [x] Magic + `HIG_State` struct and recovery hook

### Week 2 — Indicators

- [x] `iATR` + `iCustom` VWAP (no extra params if all `InpVWAP_P*` are zero)
- [x] Prior D1 high/low copied into `SHIGBarSnapshot` (for logs / future use)
- [x] `OnDeinit` releases handles

### Week 3 — Signal

- [x] Closed bar (shift `1`) only; long/short AND-chain per `concept.md`
- [x] Trade permission mask
- [x] `InpDryRun` to log signals without sending

### Week 4 — Risk + execution

- [x] Spread, equity ratio, cooldown, max trades, stops level, symbol trade mode
- [x] Fixed lot and optional `%` risk sizing
- [x] SL points or ATR mult; TP = RR × SL distance
- [x] Netting: close opposite before flip; same-side pyramid skipped
- [x] `CTrade` market buy/sell with slippage / deviation inputs

### Week 5 — Lifecycle

- [x] `OnTradeTransaction` on `TRADE_TRANSACTION_DEAL_ADD`: magic/symbol filter, `DEAL_ENTRY_IN` updates cooldown + `g_signal_filled_bar`
- [x] `OnInit`: `HIG_State_RecoverFromTerminal` (position count + last deal time)
- [x] One evaluation per new chart bar; `g_signal_filled_bar` prevents duplicate entry on same signal candle after a fill
