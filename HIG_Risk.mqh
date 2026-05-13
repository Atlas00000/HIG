//+------------------------------------------------------------------+
//| HIG_Risk.mqh — gates before OrderSend                             |
//+------------------------------------------------------------------+
#ifndef HIG_RISK_MQH
#define HIG_RISK_MQH

string HIG_Risk_BlockReason(const string sym, const ulong magic,
                            const ENUM_ORDER_TYPE otype,
                            const double entry_price, const double sl_price)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return "TERMINAL_TRADE_OFF";
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return "EA_TRADE_OFF";

   long mode = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   if(otype == ORDER_TYPE_BUY)
     {
      if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_SHORTONLY ||
         mode == SYMBOL_TRADE_MODE_CLOSEONLY)
         return "SYMBOL_NO_BUY";
     }
   else
     {
      if(mode == SYMBOL_TRADE_MODE_DISABLED || mode == SYMBOL_TRADE_MODE_LONGONLY ||
         mode == SYMBOL_TRADE_MODE_CLOSEONLY)
         return "SYMBOL_NO_SELL";
     }

   int spr = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spr > InpMaxSpreadPoints)
      return "BLOCK_SPREAD_HIGH";

   if(InpMinEquityRatio > 0.0)
     {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal <= 0.0 || eq / bal < InpMinEquityRatio)
         return "BLOCK_EQUITY";
     }

   if(InpCooldownSeconds > 0 && g_hig.last_deal_time > 0)
     {
      if((TimeCurrent() - g_hig.last_deal_time) < InpCooldownSeconds)
         return "BLOCK_COOLDOWN";
     }

   if(g_hig.open_positions >= InpMaxOpenTrades)
      return "BLOCK_MAX_TRADES";

   double sl_dist = MathAbs(entry_price - sl_price);
   if(sl_dist < _Point)
      return "BLOCK_SL_DIST";

   double min_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double lots = InpFixedLots;
   if(InpUseRiskPercent)
     {
      double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tv > 0.0 && ts > 0.0)
        {
         double loss_per_lot = (sl_dist / ts) * tv;
         if(loss_per_lot > 0.0)
            lots = risk_money / loss_per_lot;
        }
     }

   lots = MathFloor(lots / step) * step;
   lots = MathMax(min_lot, MathMin(max_lot, lots));
   if(lots < min_lot - 1e-12)
      return "BLOCK_LOT";

   int stops = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops > 0)
     {
      double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(otype == ORDER_TYPE_BUY)
        {
         if((entry_price - sl_price) < stops * pt - 1e-10)
            return "BLOCK_STOPS_LEVEL";
        }
      else
        {
         if((sl_price - entry_price) < stops * pt - 1e-10)
            return "BLOCK_STOPS_LEVEL";
        }
     }

   return "";
  }

double HIG_Risk_NormalizedLots(const string sym, const ulong magic,
                               const ENUM_ORDER_TYPE otype,
                               const double entry_price, const double sl_price)
  {
   double min_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double sl_dist = MathAbs(entry_price - sl_price);
   double lots = InpFixedLots;
   if(InpUseRiskPercent)
     {
      double risk_money = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double tv = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double ts = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      if(tv > 0.0 && ts > 0.0)
        {
         double loss_per_lot = (sl_dist / ts) * tv;
         if(loss_per_lot > 0.0)
            lots = risk_money / loss_per_lot;
        }
     }
   lots = MathFloor(lots / step) * step;
   return MathMax(min_lot, MathMin(max_lot, lots));
  }

#endif // HIG_RISK_MQH
