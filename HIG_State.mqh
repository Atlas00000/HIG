//+------------------------------------------------------------------+
//| HIG_State.mqh — runtime state, recovery-friendly                  |
//+------------------------------------------------------------------+
#ifndef HIG_STATE_MQH
#define HIG_STATE_MQH

struct SHIGState
  {
   datetime last_bar_time;              // iTime(0) last seen
   datetime last_entry_signal_bar;     // iTime(...,1) used for last entry attempt/success
   datetime last_deal_time;            // last OUR deal time (cooldown)
   int      open_positions;             // our magic + symbol
   bool     pending_order_send;        // request in flight
   long     margin_mode;
   bool     fifo_close;
  };

SHIGState g_hig;

void HIG_State_Reset()
  {
   ZeroMemory(g_hig);
  }

int HIG_State_CountOurPositions(const string sym, const ulong magic)
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != sym)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      n++;
     }
   return n;
  }

datetime HIG_State_LastDealTimeFromHistory(const string sym, const ulong magic)
  {
   const int days = 30;
   datetime from = TimeCurrent() - days * 86400;
   if(!HistorySelect(from, TimeCurrent()))
      return 0;
   datetime newest = 0;
   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; i--)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != sym)
         continue;
      datetime t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(t > newest)
         newest = t;
     }
   return newest;
  }

void HIG_State_RecoverFromTerminal(const string sym, const ulong magic)
  {
   g_hig.open_positions = HIG_State_CountOurPositions(sym, magic);
   datetime hist = HIG_State_LastDealTimeFromHistory(sym, magic);
   if(hist > g_hig.last_deal_time)
      g_hig.last_deal_time = hist;
   g_hig.margin_mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   g_hig.fifo_close = (AccountInfoInteger(ACCOUNT_FIFO_CLOSE) != 0);
   HIG_Log_Line("STATE", "POSITION_RECOVERED",
                StringFormat("open=%d margin=%d fifo=%d lastDeal=%s",
                             g_hig.open_positions, (int)g_hig.margin_mode, (int)g_hig.fifo_close,
                             TimeToString(g_hig.last_deal_time, TIME_DATE | TIME_SECONDS)));
  }

#endif // HIG_STATE_MQH
