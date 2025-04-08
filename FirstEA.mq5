#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;
input int length = 14;
input string Commentary = NULL;
input double Lot_size = 0.01;
input int streak_number = 6;
datetime lastCandleTime = 0;
input int tp_points = 20;
input int sl_points = 50;

void OnInit(){
   Print("EA has been initialized");
}

void OnTick(){
   datetime currentCandleTime = iTime(NULL, PERIOD_CURRENT, 0);
   
   // Only process logic on new candle
   if (currentCandleTime != lastCandleTime)
   {
      lastCandleTime = currentCandleTime;
      
      // Check for bullish streak (green candles)
      int bullishStreak = 0;
      for (int i = 1; i <= streak_number; i++) {
         double curr_open = iOpen(NULL, PERIOD_CURRENT, i);
         double curr_close = iClose(NULL, PERIOD_CURRENT, i);
         
         if (curr_close > curr_open) { // Green candle
            bullishStreak++;
         } else {
            break; // Break on first non-green candle
         }
      }
      
      // Check for bearish streak (red candles)
      int bearishStreak = 0;
      for (int i = 1; i <= streak_number; i++) {
         double curr_open = iOpen(NULL, PERIOD_CURRENT, i);
         double curr_close = iClose(NULL, PERIOD_CURRENT, i);
         
         if (curr_close < curr_open) { // Red candle
            bearishStreak++;
         } else {
            break; // Break on first non-red candle
         }
      }
      
      // Execute trades if streak conditions are met
      if (bullishStreak >= streak_number) {
         double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
         double tp = entry - tp_points * Point();
         double sl = entry + sl_points * Point();
         trade.Sell(Lot_size, NULL, entry, sl, tp, Commentary);
         Print("Buy signal: ", streak_number, " consecutive green candles detected");
      }
      
      if (bearishStreak >= streak_number) {
         double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
         double tp = entry + tp_points * Point();
         double sl = entry - sl_points * Point();
         trade.Buy(Lot_size, NULL, entry, sl, tp, Commentary);
         Print("Sell signal: ", streak_number, " consecutive red candles detected");
      }
   }
}