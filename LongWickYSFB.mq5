#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

CTrade trade;
input double Lot_size = 0.01;
datetime lastCandleTime = 0;
input double sl_atr_multiplier = 2;
input double tp_atr_multiplier = 1;
input int atr_period = 14;
input int candlebody_avg_lookback = 20;
double atrValue;

void execute_sell(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
   double tp = entry - atrValue*tp_atr_multiplier;
   double sl = entry + atrValue*sl_atr_multiplier;
   trade.Sell(Lot_size, NULL, entry, sl, tp);
}


void execute_buy(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
   double tp = entry + atrValue*tp_atr_multiplier;
   double sl = entry - atrValue*sl_atr_multiplier;
   trade.Buy(Lot_size, NULL, entry, sl, tp);
}

void OnTick(){
   datetime currentCandleTime = iTime(NULL, PERIOD_CURRENT, 0);
   if (currentCandleTime != lastCandleTime)
   {
      lastCandleTime = currentCandleTime;

      int handleATR = iATR(NULL, PERIOD_CURRENT, atr_period);
      double atrBuffer[1];
      CopyBuffer(handleATR, 0, 0, 1, atrBuffer);
      atrValue = atrBuffer[0];
      
      double prev_open = iOpen(NULL, PERIOD_CURRENT, 1);
      double prev_close = iClose(NULL, PERIOD_CURRENT, 1);
      double prev_high = iHigh(NULL, PERIOD_CURRENT, 1);
      double prev_low = iLow(NULL, PERIOD_CURRENT, 1);
      
      double upper_wick_length;
      double lower_wick_length;
      
      double candle_body_length = MathAbs(prev_open-prev_close);
      if (prev_close>prev_open){ //green candle
         upper_wick_length = prev_high - prev_close;
         lower_wick_length = prev_open - prev_low;
      }else if (prev_close<=prev_open){ //red candle
         upper_wick_length = prev_high - prev_open;
         lower_wick_length = prev_close - prev_low;      
      }
      
      double past_candlebody_avg;
      double sum_candlebodies;
      for(int i=1;i<=candlebody_avg_lookback;i++){
         double curr_open = iOpen(NULL,PERIOD_CURRENT,i);
         double curr_close = iClose(NULL,PERIOD_CURRENT,i);
         double curr_candle_body_length = MathAbs(curr_open-curr_close);
         sum_candlebodies = sum_candlebodies + curr_candle_body_length ;
      }
      past_candlebody_avg = sum_candlebodies/candlebody_avg_lookback;
      
      double upwick_body_ratio = upper_wick_length/candle_body_length;
      double lowick_body_ratio = lower_wick_length/candle_body_length;
      double body_to_avg_ratio = candle_body_length/past_candlebody_avg;
      bool buying_condition = false;
      bool selling_condition = false;
      
      if(upwick_body_ratio>=3 && lowick_body_ratio<=2 && body_to_avg_ratio>=0.3){selling_condition=true;}
      else if(lowick_body_ratio>=3 && upwick_body_ratio<=2 && body_to_avg_ratio>=0.3){buying_condition=true;}
      
      if (buying_condition == true) {execute_buy();}
      
      if (selling_condition == true) {execute_sell();}
   }
}

//works best with 1h 