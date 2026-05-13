//+------------------------------------------------------------------+
//| HIG_Execution.mqh — market orders, SL/TP, netting close           |
//+------------------------------------------------------------------+
#ifndef HIG_EXECUTION_MQH
#define HIG_EXECUTION_MQH

#include <Trade/Trade.mqh>

static CTrade s_hig_trade;

void HIG_Exec_Init(const ulong magic, const string sym)
  {
   s_hig_trade.SetExpertMagicNumber((int)magic);
   s_hig_trade.SetDeviationInPoints(InpDeviationPoints);
   s_hig_trade.SetTypeFillingBySymbol(sym);
  }

bool HIG_Exec_FindPosition(const string sym, const ulong magic,
                          const int want_dir,
                          ulong &ticket_out, ENUM_POSITION_TYPE &type_out)
  {
   ticket_out = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      int d = (pt == POSITION_TYPE_BUY) ? 1 : -1;
      if(want_dir != 0 && d != want_dir)
         continue;
      ticket_out = t;
      type_out = pt;
      return true;
     }
   return false;
  }

bool HIG_Exec_CloseOur(const string sym, const ulong magic)
  {
   ulong tk;
   ENUM_POSITION_TYPE pt;
   if(!HIG_Exec_FindPosition(sym, magic, 0, tk, pt))
      return true;
   if(!s_hig_trade.PositionClose(tk, InpSlippagePoints))
     {
      HIG_Log_Line("TRADE", "ORDER_SEND_FAILED", StringFormat("close %s %s", (string)tk, s_hig_trade.ResultRetcodeDescription()));
      return false;
     }
   return true;
  }

bool HIG_Exec_ShouldSkipPyramid(const string sym, const ulong magic,
                                const ENUM_ORDER_TYPE otype, const bool is_netting)
  {
   ulong tk;
   ENUM_POSITION_TYPE pt;
   if(!HIG_Exec_FindPosition(sym, magic, 0, tk, pt))
      return false;
   int want = (otype == ORDER_TYPE_BUY) ? 1 : -1;
   int have = (pt == POSITION_TYPE_BUY) ? 1 : -1;
   if(is_netting)
      return (want == have);
   return (want == have);
  }

bool HIG_Exec_NeedCloseOpposite(const string sym, const ulong magic,
                                const ENUM_ORDER_TYPE otype, const bool is_netting)
  {
   if(!is_netting)
      return false;
   ulong tk;
   ENUM_POSITION_TYPE pt;
   if(!HIG_Exec_FindPosition(sym, magic, 0, tk, pt))
      return false;
   int want = (otype == ORDER_TYPE_BUY) ? 1 : -1;
   int have = (pt == POSITION_TYPE_BUY) ? 1 : -1;
   return (want != have);
  }

bool HIG_Exec_OpenMarket(const string sym, const ulong magic,
                         const ENUM_ORDER_TYPE otype,
                         const double sl_price, const double tp_price,
                         const double lots)
  {
   const bool netting = (AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_NETTING);

   if(HIG_Exec_NeedCloseOpposite(sym, magic, otype, netting))
     {
      if(!HIG_Exec_CloseOur(sym, magic))
         return false;
      Sleep(250);
      g_hig.open_positions = HIG_State_CountOurPositions(sym, magic);
     }

   if(HIG_Exec_ShouldSkipPyramid(sym, magic, otype, netting))
      return true;

   bool ok = false;
   if(otype == ORDER_TYPE_BUY)
      ok = s_hig_trade.Buy(lots, sym, 0, sl_price, tp_price, "HIG");
   else
      ok = s_hig_trade.Sell(lots, sym, 0, sl_price, tp_price, "HIG");

   if(!ok)
     {
      HIG_Log_Line("TRADE", "ORDER_SEND_FAILED", s_hig_trade.ResultRetcodeDescription());
      return false;
     }
   HIG_Log_Line("TRADE", "ORDER_SEND_SUCCESS", StringFormat("%s vol=%.2f", EnumToString(otype), lots));
   return true;
  }

#endif // HIG_EXECUTION_MQH
