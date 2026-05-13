//+------------------------------------------------------------------+
//| HIG_Config.mqh — inputs (input group = section headers in UI)     |
//+------------------------------------------------------------------+
#ifndef HIG_CONFIG_MQH
#define HIG_CONFIG_MQH

enum ENUM_HIG_TRADE_PERM
  {
   HIG_PERM_BOTH = 0,
   HIG_PERM_BUY_ONLY,
   HIG_PERM_SELL_ONLY
  };

enum ENUM_HIG_SL_MODE
  {
   HIG_SL_ATR = 0,
   HIG_SL_POINTS
  };

enum ENUM_HIG_VWAP_SOURCE
  {
   HIG_VWAP_BUILTIN = 0, // broker-day VWAP from chart bars (no .ex5)
   HIG_VWAP_ICUSTOM = 1  // iCustom — file must exist under MQL5\\Indicators\\
  };

input group "Debug"
input bool InpDebugVerbose = false;

input group "Signal (tuned for M1/M5 — more sensitive)"
input double InpValueBandATR = 2.2;      // VWAP value-zone width (ATR mult); higher = easier zone
input double InpMinDispATR = 0.12;     // min |close−VWAP| in ATR; lower = more signals on small TFs
input double InpWickBodyMult = 0.0;    // rejection wick ≥ body×this (0 = off; body direction still required)
input double InpMaxATR = 0.0;            // block if ATR(1) > this (0 = disabled)

input group "VWAP"
input ENUM_HIG_VWAP_SOURCE InpVWAP_Source = HIG_VWAP_BUILTIN;
input string InpVWAP_Indicator = "VWAP"; // iCustom only: Folder\\Name without .ex5
input int    InpVWAP_Buffer = 0;
input long   InpVWAP_P1 = 0;
input long   InpVWAP_P2 = 0;
input long   InpVWAP_P3 = 0;
input double InpVWAP_P4 = 0.0;
input double InpVWAP_P5 = 0.0;

input group "ATR (shorter period reacts faster on M1/M5)"
input int    InpATR_Period = 10;

input group "Risk"
input ulong  InpMagic = 20260513;
input bool   InpUseRiskPercent = false;
input double InpRiskPercent = 1.0;
input double InpFixedLots = 0.01;
input int    InpMaxSpreadPoints = 55;   // M1/M5 often wider; raise to reduce spread blocks
input int    InpMaxOpenTrades = 5;     // more concurrent data collection
input int    InpCooldownSeconds = 20;   // shorter pause between new entries
input double InpMinEquityRatio = 0.0;  // min equity/balance (0 = off)
input ENUM_HIG_SL_MODE InpSLMode = HIG_SL_ATR;
input int    InpSLPoints = 120;        // if using fixed points on small TF
input double InpSL_ATR_Mult = 1.15;    // slightly tighter vs 1.5 for small-bar ATR scale
input double InpRR = 2.0;

input group "Execution"
input int    InpSlippagePoints = 25;
input int    InpDeviationPoints = 12;

input group "Trade permissions"
input ENUM_HIG_TRADE_PERM InpTradePerm = HIG_PERM_BOTH;

input group "Safety"
input bool   InpDryRun = false;        // false = live sends (still subject to tester / Algo Trading)

#endif // HIG_CONFIG_MQH
