We are building an MT5 Expert Advisor (EA) centred around the following trading concept and system architecture:
[Hedged Institutional Grid
Core Edge
Use opposing exposure around high-liquidity zones to capture rotational inefficiencies.

Indicator Blend
VWAP
Volume Profile
ATR
Session Levels

Core Logic
Long grid below VWAP/value
Short grid above VWAP/value
Mean reversion toward institutional fair value
Hedge exposure reduces directional risk

Best Conditions
liquid forex pairs
indices
high-volume sessions

Main Risk
Strong directional trend with value migration.

]
Current Development Scope (Phase 1):
The focus right now is strictly on building the automated execution engine based on the selected indicators and signal logic. We are intentionally keeping the system lightweight and modular at this stage.
Important:
Do NOT introduce advanced filtering, AI layers, portfolio management, adaptive optimisation, or overengineered logic yet.
Do NOT add unnecessary complexity outside the core execution workflow.
Discretionary session filters (time-of-day gates, news blackouts, “only London” style windows, multi-session micro-rules) are out of scope for Phase 1. Indicator anchors are still in scope: daily VWAP reset at broker day open and prior-session high/low where specified below—these define inputs to the signal, not optional trading calendars.
The goal is simply to automate trade execution reliably using the selected indicators and trading conditions.
Core Objective:
Build a configurable execution engine capable of:
Reading indicator values and market conditions in real time
Evaluating entry conditions
Executing buy/sell trades automatically
Managing basic trade risk
Providing clean parameter configuration for optimization and future scaling
Execution Engine Requirements:
Configurable indicator inputs
Configurable entry conditions
Buy/sell execution logic
Support for market orders initially
Clean order validation before execution
Low-latency and lightweight processing
Modular architecture for future expansion
Basic Risk Management & Position Sizing:
Include foundational risk and trade management features only, such as the following:
Fixed lot size input
Optional risk-based position sizing (percent risk per trade)
Stop Loss (fixed points/pips or ATR-based if applicable)
Take Profit configuration
Risk-to-reward ratio support
Maximum spread filter
Slippage control
Maximum simultaneous open trades
Basic cooldown between trades
Magic number management
Equity/balance safety checks
Configurable trading permissions (buy only / sell only / both)
One Symbol vs Multi-Symbol
Use:
Single symbol
Single timeframe
Based strictly on the current chart
This is the correct decision for Phase 1.
Benefits:
Simpler execution flow
Easier debugging
Lower CPU usage
Cleaner state management
More reliable order tracking
Avoids synchronization complexity
Architecture assumption:
One EA instance per chart
One symbol context
One timeframe context
Avoid for now:
multi-symbol scanning
centralized portfolio engine
cross-chart communication
symbol routing
correlation logic
Future extensibility:
Your modular structure should still isolate the following:
signal engine
execution engine
risk engine
This makes future multi-symbol expansion possible without rewriting the core.
The EA should:
Be modular and extensible
Use clean separation of concerns
Support future integration of:
filters
session logic
AI optimization
volatility layers
portfolio controls
advanced trade management
multi-strategy routing
Architecture Goals:
Clean and maintainable codebase
Production-style folder structure
Clear module responsibilities
Configurable engine design
Scalable architecture without premature complexity
High execution reliability
Easy debugging and testing
Suggested Focus Areas:
Signal evaluation pipeline
Indicator management system
Trade execution module
Risk management module
Position sizing engine
Configuration/input management
Logging and debugging utilities
State and trade tracking
What I need from you:
Design the execution engine architecture
Define module responsibilities and execution workflow
Recommend an MT5 production-grade folder structure
Suggest industry best practices for EA development
Keep implementation practical, scalable, and efficient
Avoid unnecessary abstraction or feature creep
Prioritize configurability, maintainability, and execution reliability
The current objective is NOT strategy perfection or advanced intelligence.
The objective is building a strong, configurable execution foundation first.

Resolved gaps (implementation spec)
Concrete entry/exit rules
Long setup:
Price below VWAP
Price inside or below lower value zone (Volume Profile proxy band)
Distance from VWAP ≥ configurable ATR multiple
Current candle closes bullish OR rejection wick condition
Spread filter passes
Short setup:
Price above VWAP
Price inside or above upper value zone
Distance from VWAP ≥ configurable ATR multiple
Current candle closes bearish OR rejection wick condition
Spread filter passes
Boolean structure:
(VWAP condition) AND (Value condition) AND (ATR displacement) AND (Candle confirmation) AND (Risk filters)
Signal timing:
Evaluate only on closed candle (OnTick + new bar detection)
Prevent intrabar repaint instability in Phase 1
Invalidation:
Price closes back through VWAP before entry
ATR volatility exceeds max threshold
Spread exceeds max spread
Existing trade count limit reached
Cooldown active
Grid vs single entry
Phase 1 should use:
One entry per signal initially
“Grid-ready architecture” without activating full laddering yet
Suggested implementation:
First grid leg only
Future grid expansion handled later through reusable position manager
Hedging representation:
Hedge-capable accounts:
Allow simultaneous buy/sell positions
Netting accounts:
Only one directional net position exists
Reverse signal closes/reduces existing exposure
Add runtime detection (AccountInfoInteger):
ACCOUNT_MARGIN_MODE (hedging vs netting)
ACCOUNT_FIFO_CLOSE (FIFO close ordering on hedging accounts when exposed by the terminal; document broker quirks if behaviour differs)
Architecture:
Position tracker should record direction and magic for this symbol only; structure data so future grids can group legs without a redesign
Indicator contracts
VWAP:
Prefer custom VWAP indicator handle
Inputs:
session anchor
applied price
ATR:
Native iATR
Default: period 14
Volume Profile:
Phase 1 recommendation:
simplified proxy instead of full institutional VP engine
Use:
rolling high-volume range
or VWAP deviation bands
Full VP should be deferred
Session Levels:
Prior session high/low
Asian/London/NY optional later
Handles:
Create once in OnInit
Reuse buffers
Release in OnDeinit
VWAP/session definition
Recommended:
Daily anchored VWAP
Reset at broker day open
Why:
Consistent optimization/testing behavior
Matches institutional intraday fair value concept
Session rules:
One reset per trading day
No rolling VWAP in Phase 1
Important:
Broker timezone dependency must be documented
Log session reset timestamps
ATR usage
ATR should support:
Stop loss sizing
Grid spacing preparation
Phase 1 live use:
SL calculation
Entry displacement filter
Timeframe:
Use chart timeframe only
Avoid:
Multi-timeframe ATR complexity for now
R:R vs TP
Recommended Phase 1:
SL derived from ATR or fixed points
TP derived from configurable Risk:Reward ratio
Example:
TP = Entry ± (SL distance × RR)
Avoid partial closes initially:
Adds execution/state complexity
Harder reconciliation
More edge cases after reconnects
Future-ready (Phase 2+):
Keep order placement behind one small function or class so partial closes and grid legs can be added without rewriting risk checks
Order lifecycle
Use:
OnTradeTransaction
Position reconciliation on startup
Required behaviors:
Prevent duplicate sends
Confirm fills before state update
Rebuild internal trade state after terminal restart
Validate magic number ownership
Recommended tracking:
Pending request state
Last signal timestamp
Last trade direction
Position ticket cache
On disconnect/reconnect:
Re-scan live positions
Reconstruct EA state from terminal/account data
Testing (owner-run; EA supplies stable logging and recovery hooks only)
Strategy Tester assumptions:
Every tick based on real ticks
Fixed spread optional for baseline
Variable spread stress test afterward
Validate:
Stops level
Freeze level
Min lot/max lot
Margin requirements
Demo checklist:
Entry execution accuracy
SL/TP placement
Spread filter behavior
Restart recovery
Duplicate prevention
Logging clarity
Hedging/netting behavior
Cooldown enforcement
Logging spec
Log categories:
Signal evaluation
Risk rejection
Trade request
Trade result
State recovery
Critical errors
Example logs:
SIGNAL_LONG_VALID
BLOCK_SPREAD_HIGH
BLOCK_COOLDOWN
ORDER_SEND_SUCCESS
ORDER_SEND_FAILED
POSITION_RECOVERED
Avoid log spam:
Only log on state changes
Optional verbose debug mode
Tick-by-tick logs disabled by default
Parameter surface
Group inputs:
Signal Settings
VWAP Settings
ATR Settings
Risk Settings
Execution Settings
Trade Permissions
Debug Settings
Optimization-safe:
ATR multiplier
RR ratio
SL ATR multiplier
Spread filter
Cooldown
Dangerous/curve-fit prone:
Too many confirmation layers
Excessive VP tuning
Session micro-filters
Narrow time windows
Highly granular ATR values
Best practice:
Keep parameter count intentionally small in Phase 1
Prioritize robustness over optimization depth