//+------------------------------------------------------------------+
//|                                                          HIG.mq5 |
//|                        Hedged Institutional Grid — Phase 1 engine |
//+------------------------------------------------------------------+
#property copyright "2026"
#property version   "1.00"
#include "HIG_Config.mqh"
#include "HIG_Log.mqh"
#include "HIG_State.mqh"
#include "HIG_Indicators.mqh"
#include "HIG_Signal.mqh"
#include "HIG_Risk.mqh"
#include "HIG_Execution.mqh"

datetime g_chart_bar_open = 0;
datetime g_pending_signal_bar = 0;
datetime g_signal_filled_bar = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   HIG_State_Reset();
   HIG_Exec_Init(InpMagic, _Symbol);
   if(!HIG_Indicators_Init(_Symbol, PERIOD_CURRENT))
      return INIT_FAILED;
   HIG_State_RecoverFromTerminal(_Symbol, InpMagic);
   g_chart_bar_open = iTime(_Symbol, PERIOD_CURRENT, 0);
   HIG_Log_Line("SYS", "INIT_OK", InpDryRun ? "DRY_RUN" : "LIVE_SEND");
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   HIG_Indicators_Deinit();
  }

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   const ulong deal_id = trans.deal;
   if(deal_id == 0)
      return;
   HistorySelect(0, TimeCurrent());
   if(!HistoryDealSelect(deal_id))
      return;
   if(HistoryDealGetString(deal_id, DEAL_SYMBOL) != _Symbol)
      return;
   if((ulong)HistoryDealGetInteger(deal_id, DEAL_MAGIC) != InpMagic)
      return;

   const long entry = HistoryDealGetInteger(deal_id, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN)
     {
      g_hig.last_deal_time = (datetime)HistoryDealGetInteger(deal_id, DEAL_TIME);
      g_signal_filled_bar = g_pending_signal_bar;
      HIG_Log_Line("TRADE", "DEAL_IN", TimeToString(g_hig.last_deal_time, TIME_DATE | TIME_SECONDS));
     }

   g_hig.open_positions = HIG_State_CountOurPositions(_Symbol, InpMagic);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t0 == 0)
      return;
   if(t0 == g_chart_bar_open)
      return;
   g_chart_bar_open = t0;

   SHIGBarSnapshot bar;
   if(!HIG_Indicators_FetchClosedBar(_Symbol, PERIOD_CURRENT, bar))
     {
      HIG_Log_Line("DBG", "BAR_FETCH_FAIL", "");
      return;
     }

   if(InpDebugVerbose)
      HIG_Log_Line("DBG", "BAR",
                   StringFormat("t=%s c=%.5f vwap=%.5f atr=%.5f d1h=%.5f d1l=%.5f",
                                TimeToString(bar.bar_time, TIME_DATE | TIME_MINUTES),
                                bar.close, bar.vwap, bar.atr, bar.prior_d1_high, bar.prior_d1_low));

   string sreason;
   ENUM_HIG_SIGNAL sig = HIG_Signal_Evaluate(bar, sreason);

   if(sig == HIG_SIG_LONG)
      HIG_Log_Line("SIGNAL", "SIGNAL_LONG_VALID", sreason);
   else if(sig == HIG_SIG_SHORT)
      HIG_Log_Line("SIGNAL", "SIGNAL_SHORT_VALID", sreason);

   if(sig == HIG_SIG_NONE)
      return;

   if(g_signal_filled_bar == bar.bar_time)
      return;

   if(InpDryRun)
     {
      HIG_Log_Line("RISK", "DRY_RUN_SKIP_SEND", "");
      return;
     }

   const string sym = _Symbol;
   const int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   const double entry = (sig == HIG_SIG_LONG) ? ask : bid;

   double sl_dist = 0.0;
   if(InpSLMode == HIG_SL_POINTS)
      sl_dist = InpSLPoints * pt;
   else
      sl_dist = MathMax(bar.atr, pt) * InpSL_ATR_Mult;

   double sl = 0.0, tp = 0.0;
   if(sig == HIG_SIG_LONG)
     {
      sl = NormalizeDouble(entry - sl_dist, dg);
      tp = NormalizeDouble(entry + InpRR * sl_dist, dg);
     }
   else
     {
      sl = NormalizeDouble(entry + sl_dist, dg);
      tp = NormalizeDouble(entry - InpRR * sl_dist, dg);
     }

   const ENUM_ORDER_TYPE otype = (sig == HIG_SIG_LONG) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string block = HIG_Risk_BlockReason(sym, InpMagic, otype, entry, sl);
   if(block != "")
     {
      HIG_Log_Line("RISK", block, "");
      return;
     }

   const double lots = HIG_Risk_NormalizedLots(sym, InpMagic, otype, entry, sl);
   g_pending_signal_bar = bar.bar_time;
   HIG_Exec_OpenMarket(sym, InpMagic, otype, sl, tp, lots);
   g_hig.open_positions = HIG_State_CountOurPositions(sym, InpMagic);
  }

//+------------------------------------------------------------------+
