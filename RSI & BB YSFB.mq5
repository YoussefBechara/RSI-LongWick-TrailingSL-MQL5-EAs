//+------------------------------------------------------------------+
//|                                      RSI_Bollinger_Breakout_EA.mq5 |
//|                                                                    |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

// Input parameters
input int                 RSI_Period = 14;           // RSI period
input int                 BB_Period = 20;            // Bollinger Bands period
input double              BB_Deviation = 2.0;        // Bollinger Bands deviation
input int                 RSI_Overbought = 80;       // RSI overbought level
input int                 RSI_Oversold = 20;         // RSI oversold level
input double              Lot_Size = 0.01;            // Lot size
input int                 Stop_Loss = 100;           // Stop Loss in points
input int                 Take_Profit = 200;         // Take Profit in points
input bool                UseTrailingStop = false;   // Use trailing stop
input int                 TrailingStop = 50;         // Trailing stop in points
input int                 TrailingStep = 10;         // Trailing step in points

// Global variables
int rsi_handle;
int bb_handle;
int bar_count;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create RSI indicator handle
   rsi_handle = iRSI(NULL, 0, RSI_Period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Error creating RSI indicator");
      return(INIT_FAILED);
   }
   
   // Create Bollinger Bands indicator handle
   bb_handle = iBands(NULL, 0, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   if(bb_handle == INVALID_HANDLE)
   {
      Print("Error creating Bollinger Bands indicator");
      return(INIT_FAILED);
   }
   
   bar_count = iBars(NULL, 0);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(rsi_handle);
   IndicatorRelease(bb_handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   int current_bars = iBars(NULL, 0);
   if(current_bars <= bar_count) return;
   bar_count = current_bars;
   
   // Get indicator values
   double rsi_values[];
   double bb_upper[];
   double bb_lower[];
   double bb_middle[];
   double close_prices[];
   
   // Define array sizes
   ArraySetAsSeries(rsi_values, true);
   ArraySetAsSeries(bb_upper, true);
   ArraySetAsSeries(bb_lower, true);
   ArraySetAsSeries(bb_middle, true);
   ArraySetAsSeries(close_prices, true);
   
   // Fill arrays with indicator values
   CopyBuffer(rsi_handle, 0, 0, 3, rsi_values);
   CopyBuffer(bb_handle, 1, 0, 3, bb_upper);
   CopyBuffer(bb_handle, 2, 0, 3, bb_lower);
   CopyBuffer(bb_handle, 0, 0, 3, bb_middle);
   
   // Get price data
   CopyClose(NULL, 0, 0, 3, close_prices);
   
   // Check if we already have a position
   if(PositionsTotal() > 0) 
   {
      // Manage existing trades (trailing stop)
      if(UseTrailingStop) ManageTrailingStop();
      return;
   }
   
   // Check for sell signal: RSI overbought (>70) and previous candle broke above upper Bollinger Band
   if(rsi_values[1] > RSI_Overbought && close_prices[2] <= bb_upper[2] && close_prices[1] > bb_upper[1])
   {
      ExecuteOrder(ORDER_TYPE_SELL);
   }
   
   // Check for buy signal: RSI oversold (<30) and previous candle broke below lower Bollinger Band
   if(rsi_values[1] < RSI_Oversold && close_prices[2] >= bb_lower[2] && close_prices[1] < bb_lower[1])
   {
      ExecuteOrder(ORDER_TYPE_BUY);
   }
}

//+------------------------------------------------------------------+
//| Execute a trade order                                           |
//+------------------------------------------------------------------+
void ExecuteOrder(ENUM_ORDER_TYPE order_type)
{
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   // Set order parameters
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = Lot_Size;
   request.type = order_type;
   request.price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   request.deviation = 10;
   request.magic = 123456;
   
   // Set stop loss and take profit
   double points = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * points;
   
   if(order_type == ORDER_TYPE_BUY)
   {
      request.sl = (Stop_Loss > 0) ? request.price - Stop_Loss * points : 0;
      request.tp = (Take_Profit > 0) ? request.price + Take_Profit * points : 0;
   }
   else
   {
      request.sl = (Stop_Loss > 0) ? request.price + Stop_Loss * points : 0;
      request.tp = (Take_Profit > 0) ? request.price - Take_Profit * points : 0;
   }
   
   // Check if SL and TP are valid
   if(request.sl != 0 && MathAbs(request.price - request.sl) < stop_level)
   {
      Print("Stop Loss is too close to current price. Minimum distance: ", stop_level);
      return;
   }
   
   if(request.tp != 0 && MathAbs(request.price - request.tp) < stop_level)
   {
      Print("Take Profit is too close to current price. Minimum distance: ", stop_level);
      return;
   }
   
   // Send order
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
      return;
   }
   
   // Print order details
   Print("Order placed: ", EnumToString(order_type), " Price: ", request.price, " SL: ", request.sl, " TP: ", request.tp);
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;
      
      double position_sl = PositionGetDouble(POSITION_SL);
      double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double points = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
      double stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * points;
      
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      // Calculate new stop loss
      double new_sl = 0;
      
      if(position_type == POSITION_TYPE_BUY)
      {
         // For long positions, trail stop loss upward
         if(current_price - position_price > TrailingStop * points)
         {
            new_sl = current_price - TrailingStop * points;
            if(new_sl > position_sl + TrailingStep * points || position_sl == 0)
            {
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = Symbol();
               request.sl = new_sl;
               request.tp = PositionGetDouble(POSITION_TP);
               
               // Check if SL is valid
               if(MathAbs(current_price - new_sl) < stop_level)
               {
                  Print("New SL is too close to current price. Minimum distance: ", stop_level);
                  continue;
               }
               
               if(!OrderSend(request, result))
               {
                  Print("OrderModify error: ", GetLastError());
                  continue;
               }
               
               Print("Trailing stop updated: ", new_sl);
            }
         }
      }
      else if(position_type == POSITION_TYPE_SELL)
      {
         // For short positions, trail stop loss downward
         if(position_price - current_price > TrailingStop * points)
         {
            new_sl = current_price + TrailingStop * points;
            if(new_sl < position_sl - TrailingStep * points || position_sl == 0)
            {
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = Symbol();
               request.sl = new_sl;
               request.tp = PositionGetDouble(POSITION_TP);
               
               // Check if SL is valid
               if(MathAbs(current_price - new_sl) < stop_level)
               {
                  Print("New SL is too close to current price. Minimum distance: ", stop_level);
                  continue;
               }
               
               if(!OrderSend(request, result))
               {
                  Print("OrderModify error: ", GetLastError());
                  continue;
               }
               
               Print("Trailing stop updated: ", new_sl);
            }
         }
      }
   }
}