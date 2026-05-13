//+------------------------------------------------------------------+
//| HIG_Signal.mqh — closed bar (shift 1) only                        |
//+------------------------------------------------------------------+
#ifndef HIG_SIGNAL_MQH
#define HIG_SIGNAL_MQH

enum ENUM_HIG_SIGNAL
  {
   HIG_SIG_NONE = 0,
   HIG_SIG_LONG = 1,
   HIG_SIG_SHORT = 2
  };

bool HIG_CandleBullish(const double o, const double c)
  {
   return (c > o);
  }

bool HIG_CandleBearish(const double o, const double c)
  {
   return (c < o);
  }

bool HIG_RejectionBull(const double o, const double h, const double l, const double c, const double mult)
  {
   if(mult <= 0.0)
      return false;
   double body = MathAbs(c - o);
   if(body < _Point)
      body = _Point;
   double lower_wick = MathMin(o, c) - l;
   return (lower_wick >= mult * body);
  }

bool HIG_RejectionBear(const double o, const double h, const double l, const double c, const double mult)
  {
   if(mult <= 0.0)
      return false;
   double body = MathAbs(c - o);
   if(body < _Point)
      body = _Point;
   double upper_wick = h - MathMax(o, c);
   return (upper_wick >= mult * body);
  }

ENUM_HIG_SIGNAL HIG_Signal_Evaluate(const SHIGBarSnapshot &b, string &reason)
  {
   reason = "";
   if(!b.valid)
     {
      reason = "no_bar";
      return HIG_SIG_NONE;
     }

   if(InpMaxATR > 0.0 && b.atr > InpMaxATR)
     {
      reason = "atr_cap";
      return HIG_SIG_NONE;
     }

   const double atr = MathMax(b.atr, _Point);
   const double lower_band = b.vwap - InpValueBandATR * atr;
   const double upper_band = b.vwap + InpValueBandATR * atr;

   //--- Long
   bool L_vwap = (b.close < b.vwap);
   bool L_zone = (b.close >= lower_band && b.close < b.vwap);
   bool L_disp = ((b.vwap - b.close) >= InpMinDispATR * atr);
   bool L_candle = HIG_CandleBullish(b.open, b.close) ||
                   HIG_RejectionBull(b.open, b.high, b.low, b.close, InpWickBodyMult);

   //--- Short
   bool S_vwap = (b.close > b.vwap);
   bool S_zone = (b.close <= upper_band && b.close > b.vwap);
   bool S_disp = ((b.close - b.vwap) >= InpMinDispATR * atr);
   bool S_candle = HIG_CandleBearish(b.open, b.close) ||
                   HIG_RejectionBear(b.open, b.high, b.low, b.close, InpWickBodyMult);

   ENUM_HIG_SIGNAL raw = HIG_SIG_NONE;
   if(L_vwap && L_zone && L_disp && L_candle)
      raw = HIG_SIG_LONG;
   else if(S_vwap && S_zone && S_disp && S_candle)
      raw = HIG_SIG_SHORT;

   if(raw == HIG_SIG_NONE)
     {
      reason = "rules";
      return HIG_SIG_NONE;
     }

   if(InpTradePerm == HIG_PERM_BUY_ONLY && raw == HIG_SIG_SHORT)
     {
      reason = "perm";
      return HIG_SIG_NONE;
     }
   if(InpTradePerm == HIG_PERM_SELL_ONLY && raw == HIG_SIG_LONG)
     {
      reason = "perm";
      return HIG_SIG_NONE;
     }

   return raw;
  }

#endif // HIG_SIGNAL_MQH
