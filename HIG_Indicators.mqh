//+------------------------------------------------------------------+
//| HIG_Indicators.mqh — ATR, iCustom VWAP, prior D1 session H/L      |
//+------------------------------------------------------------------+
#ifndef HIG_INDICATORS_MQH
#define HIG_INDICATORS_MQH

int g_hig_atr = INVALID_HANDLE;
int g_hig_vwap = INVALID_HANDLE;

struct SHIGBarSnapshot
  {
   bool     valid;
   datetime bar_time;
   double   open, high, low, close;
   double   vwap;
   double   atr;
   double   prior_d1_high;
   double   prior_d1_low;
  };

double HIG_Indicators_BuiltinVwapAtShift(const string sym, const ENUM_TIMEFRAMES tf, const int shift)
  {
   if(shift < 1 || shift >= Bars(sym, tf))
      return 0.0;

   datetime t_anchor = iTime(sym, tf, shift);
   if(t_anchor == 0)
      return 0.0;

   MqlDateTime d_anchor;
   TimeToStruct(t_anchor, d_anchor);

   double sum_pv = 0.0;
   double sum_v = 0.0;

   const int max_bars = Bars(sym, tf);
   for(int i = shift; i < max_bars; i++)
     {
      datetime ti = iTime(sym, tf, i);
      if(ti == 0)
         break;
      MqlDateTime di;
      TimeToStruct(ti, di);
      if(di.day != d_anchor.day || di.mon != d_anchor.mon || di.year != d_anchor.year)
         break;

      const double h = iHigh(sym, tf, i);
      const double l = iLow(sym, tf, i);
      const double c = iClose(sym, tf, i);
      const double tp = (h + l + c) / 3.0;
      double v = (double)iVolume(sym, tf, i);
      if(v <= 0.0)
         v = 1.0;
      sum_pv += tp * v;
      sum_v += v;
     }

   if(sum_v <= 0.0)
      return iClose(sym, tf, shift);
   return sum_pv / sum_v;
  }

bool HIG_Indicators_Init(const string sym, const ENUM_TIMEFRAMES tf)
  {
   g_hig_atr = iATR(sym, tf, InpATR_Period);
   if(g_hig_atr == INVALID_HANDLE)
     {
      Print("HIG: iATR failed");
      return false;
     }

   g_hig_vwap = INVALID_HANDLE;

   if(InpVWAP_Source == HIG_VWAP_ICUSTOM)
     {
      const bool no_extra = (InpVWAP_P1 == 0 && InpVWAP_P2 == 0 && InpVWAP_P3 == 0 &&
                              InpVWAP_P4 == 0.0 && InpVWAP_P5 == 0.0);
      if(no_extra)
         g_hig_vwap = iCustom(sym, tf, InpVWAP_Indicator);
      else
         g_hig_vwap = iCustom(sym, tf, InpVWAP_Indicator,
                              InpVWAP_P1, InpVWAP_P2, InpVWAP_P3,
                              InpVWAP_P4, InpVWAP_P5);
      if(g_hig_vwap == INVALID_HANDLE)
        {
         Print("HIG: iCustom VWAP failed — place the .ex5 under MQL5\\Indicators\\ (or subfolder) and match InpVWAP_Indicator, e.g. MyPack\\MyVWAP");
         return false;
        }
     }
   else
      Print("HIG: VWAP source = built-in (broker server day, typical price × tick volume).");

   return true;
  }

void HIG_Indicators_Deinit()
  {
   if(g_hig_atr != INVALID_HANDLE)
     {
      IndicatorRelease(g_hig_atr);
      g_hig_atr = INVALID_HANDLE;
     }
   if(g_hig_vwap != INVALID_HANDLE)
     {
      IndicatorRelease(g_hig_vwap);
      g_hig_vwap = INVALID_HANDLE;
     }
  }

bool HIG_Indicators_FetchClosedBar(const string sym, const ENUM_TIMEFRAMES tf, SHIGBarSnapshot &out)
  {
   ZeroMemory(out);
   if(Bars(sym, tf) < 5)
      return false;

   datetime t1 = iTime(sym, tf, 1);
   if(t1 == 0)
      return false;

   out.bar_time = t1;
   out.open = iOpen(sym, tf, 1);
   out.high = iHigh(sym, tf, 1);
   out.low = iLow(sym, tf, 1);
   out.close = iClose(sym, tf, 1);

   if(g_hig_vwap != INVALID_HANDLE)
     {
      double v[];
      if(CopyBuffer(g_hig_vwap, InpVWAP_Buffer, 1, 1, v) != 1)
         return false;
      out.vwap = v[0];
     }
   else
      out.vwap = HIG_Indicators_BuiltinVwapAtShift(sym, tf, 1);
   if(out.vwap <= 0.0)
      out.vwap = out.close;

   double a[];
   if(CopyBuffer(g_hig_atr, 0, 1, 1, a) != 1)
      return false;
   out.atr = a[0];

   double ph[], pl[];
   if(CopyHigh(sym, PERIOD_D1, 1, 1, ph) != 1 || CopyLow(sym, PERIOD_D1, 1, 1, pl) != 1)
      return false;
   out.prior_d1_high = ph[0];
   out.prior_d1_low = pl[0];

   out.valid = true;
   return true;
  }

#endif // HIG_INDICATORS_MQH
