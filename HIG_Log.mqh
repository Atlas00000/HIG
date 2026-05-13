//+------------------------------------------------------------------+
//| HIG_Log.mqh — structured Print, no tick spam by default         |
//+------------------------------------------------------------------+
#ifndef HIG_LOG_MQH
#define HIG_LOG_MQH

void HIG_Log_Line(const string category, const string code, const string detail = "")
  {
   if(!InpDebugVerbose && category == "DBG")
      return;
   string msg = StringFormat("[%s] %s", category, code);
   if(detail != "")
      msg += " | " + detail;
   Print(msg);
  }

#endif // HIG_LOG_MQH
