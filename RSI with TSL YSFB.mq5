#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://github.com/YoussefBechara"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;

input double Lot_size = 0.01;
input double sl_atr_multiplier = 1.5;
input double tp_atr_multiplier = 2.5;
input int RSI_length = 14;
input int atr_period = 14;

datetime lastCandleTime = 0;
double RSI_value;
double atrValue;

void execute_sell(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
   double tp = entry - atrValue*tp_atr_multiplier;
   double sl = entry + atrValue*sl_atr_multiplier*1.5;
   trade.Sell(Lot_size, NULL, entry, sl, tp);
}


void execute_buy(){
   double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
   double tp = entry + atrValue*tp_atr_multiplier;
   double sl = entry - atrValue*sl_atr_multiplier*1.5;
   trade.Buy(Lot_size, NULL, entry, sl, tp);
}
input int trail_step = 3;
void TrailingStoploss(){
   for (int i = 0; i < PositionsTotal(); i++){
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentSL = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      if(profit <= 0) continue;
      
      double current_price = (type == POSITION_TYPE_BUY) ? 
                             SymbolInfoDouble(symbol, SYMBOL_BID) : 
                             SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      double newSL = 0;
      
      if(type == POSITION_TYPE_BUY){
         newSL = current_price - (atrValue * sl_atr_multiplier);
         if(newSL > currentSL){
            trade.PositionModify(ticket, newSL, takeProfit);
         }
      }
      else if(type == POSITION_TYPE_SELL){
         newSL = current_price + (atrValue * sl_atr_multiplier);
         if(newSL < currentSL || currentSL == 0){
            trade.PositionModify(ticket, newSL, takeProfit);
         }
      }
   }
}

int step_index = 0;
void OnTick(){
   datetime currentCandleTime = iTime(NULL, PERIOD_CURRENT, 0);
   if (currentCandleTime != lastCandleTime)
   {
      lastCandleTime = currentCandleTime;
      bool buying_condition = false;
      bool selling_condition = false;
 
      int handleATR = iATR(NULL, PERIOD_CURRENT, atr_period);
      double atrBuffer[1];
      CopyBuffer(handleATR, 0, 0, 1, atrBuffer);
      atrValue = atrBuffer[0];
      
      int handleRSI = iRSI(NULL, PERIOD_CURRENT, RSI_length,PRICE_CLOSE);
      double rsiBuffer[1];
      CopyBuffer(handleRSI, 0, 0, 1, rsiBuffer);
      RSI_value= rsiBuffer[0];
      
      if(RSI_value>=80){selling_condition=true;}
      else if(RSI_value<=20){buying_condition=true;}
      
      if (buying_condition == true) {execute_buy();}
      if (selling_condition == true) {execute_sell();}
      
      if (step_index >= trail_step){
         TrailingStoploss(); 
         step_index = 0;
      }
      step_index++;
   }
}
//works best with 30M 1H  2H alot