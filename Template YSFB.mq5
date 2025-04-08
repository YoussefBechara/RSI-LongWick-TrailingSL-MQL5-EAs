#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;

input double Lot_size = 0.01;
datetime lastCandleTime = 0;

void execute_sell(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
   double tp = entry - 100*Point();
   double sl = entry + 100*Point();
   trade.Sell(Lot_size, NULL, entry, sl, tp);
}

void execute_buy(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
   double tp = entry + 100*Point();
   double sl = entry - 100*Point();
   trade.Buy(Lot_size, NULL, entry, sl, tp);
}

void OnTick(){
   datetime currentCandleTime = iTime(NULL, PERIOD_CURRENT, 0);
   if (currentCandleTime != lastCandleTime)
   {
      lastCandleTime = currentCandleTime;
      bool buying_condition = false;
      bool selling_condition = false;
 
      
      
      if (buying_condition == true) {execute_buy();}
      if (selling_condition == true) {execute_sell();}
   }
}