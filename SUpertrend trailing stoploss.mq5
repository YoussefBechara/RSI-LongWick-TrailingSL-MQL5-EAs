#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01" // Version incremented

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh> // Include for CPositionInfo

CTrade trade;
CPositionInfo position; // PositionInfo object for easier access to position properties

// Input parameters
input group "Trade Settings"
input double Lot_size = 0.01;
input ulong  MagicNumber = 12345; // Magic Number for EA's trades
input int    StopLossPoints = 400; // Initial SL points (Fallback if Supertrend is invalid)
input int    TakeProfitPoints = 400; // Take Profit points
input int    TrailingStopBufferPointsinp = 10; // Buffer in points for trailing SL from Supertrend line
int TrailingStopBufferPoints = TrailingStopBufferPointsinp;

input group "SuperTrend 1"
input int    atr_period1 = 10;
input double atr_multiplier1 = 1.0;

input group "SuperTrend 2"
input int    atr_period2 = 12;
input double atr_multiplier2 = 3.0;

input group "SuperTrend 3"
input int    atr_period3 = 11;
input double atr_multiplier3 = 2.0;


input group "Moving Average"
input int    ma_period = 200;       // Moving average period
input ENUM_MA_METHOD ma_method = MODE_SMA; // Moving average method (SMA, EMA, etc.)
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // Applied price for MA calculation

input group "Ichimoku"
input int    tenkan_period = 9;        // Tenkan-sen period (Conversion Line)
input int    kijun_period = 26;        // Kijun-sen period (Base Line)
input int    senkou_span_b_period = 52; // Senkou Span B period (2nd Leading Span)

// Global variables
datetime lastCandleTime = 0;
string   trend1 = "none";
string   trend2 = "none";
string   trend3 = "none";
double   supertrend1 = 0;
double   supertrend2 = 0;
double   supertrend3 = 0;
double   point; // Store point value
int      digits; // Store digits
int      stopLevel; // Store minimum stop level distance in points

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize global variables
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   // Add a small buffer to TrailingStopBufferPoints if it's less than stopLevel
   if(TrailingStopBufferPoints < stopLevel)
     {
      Print("Warning: TrailingStopBufferPoints (", TrailingStopBufferPoints, ") is less than minimum stop level (", stopLevel, "). Adjusting buffer.");
      TrailingStopBufferPoints = stopLevel;
     }
     
   // Check if ATR periods are valid
   if(atr_period1 <= 0 || atr_period2 <= 0 || atr_period3 <= 0)
     {
      Print("Error: ATR period must be greater than 0.");
      return(INIT_FAILED);
     }
     
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(3); // Allow 3 points slippage
   trade.SetTypeFillingBySymbol(_Symbol);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Trade execution functions                                        |
//+------------------------------------------------------------------+
void execute_sell()
{
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = NormalizeDouble(entry - TakeProfitPoints * point, digits);
   double sl = 0;

   // Set initial SL based on Supertrend 1 (Downtrend)
   if(supertrend1 != 0 && trend1 == "downtrend")
     {
      // Add buffer above the downtrend Supertrend line
      sl = NormalizeDouble(supertrend1 + TrailingStopBufferPoints * point, digits);
      // Ensure SL is at least stopLevel points away from entry
      if(sl < entry + stopLevel * point)
        {
         sl = NormalizeDouble(entry + stopLevel * point, digits);
         Print("Adjusted initial Sell SL due to StopLevel. Original Supertrend SL: ", NormalizeDouble(supertrend1 + TrailingStopBufferPoints * point, digits));
        }
     }
   else
     {
      // Fallback SL if Supertrend is not ready or wrong trend
      sl = NormalizeDouble(entry + StopLossPoints * point, digits);
      Print("Warning: Using fallback SL for Sell order. Supertrend1: ", supertrend1, " Trend1: ", trend1);
     }

   if(trade.Sell(Lot_size, _Symbol, entry, sl, tp, "Sell Order by EA"))
     {
      Print("SELL order executed. Entry: ", NormalizeDouble(entry, digits), " SL: ", NormalizeDouble(sl, digits), " TP: ", NormalizeDouble(tp, digits));
     }
   else
     {
      Print("SELL order execution failed. Error: ", GetLastError());
     }
}

void execute_buy()
{
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp = NormalizeDouble(entry + TakeProfitPoints * point, digits);
   double sl = 0;

   // Set initial SL based on Supertrend 1 (Uptrend)
   if(supertrend1 != 0 && trend1 == "uptrend")
     {
      // Subtract buffer below the uptrend Supertrend line
      sl = NormalizeDouble(supertrend1 - TrailingStopBufferPoints * point, digits);
      // Ensure SL is at least stopLevel points away from entry
      if(sl > entry - stopLevel * point)
        {
         sl = NormalizeDouble(entry - stopLevel * point, digits);
         Print("Adjusted initial Buy SL due to StopLevel. Original Supertrend SL: ", NormalizeDouble(supertrend1 - TrailingStopBufferPoints * point, digits));
        }
     }
   else
     {
      // Fallback SL if Supertrend is not ready or wrong trend
      sl = NormalizeDouble(entry - StopLossPoints * point, digits);
      Print("Warning: Using fallback SL for Buy order. Supertrend1: ", supertrend1, " Trend1: ", trend1);
     }

   if(trade.Buy(Lot_size, _Symbol, entry, sl, tp, "Buy Order by EA"))
     {
      Print("BUY order executed. Entry: ", NormalizeDouble(entry, digits), " SL: ", NormalizeDouble(sl, digits), " TP: ", NormalizeDouble(tp, digits));
     }
   else
     {
      Print("BUY order execution failed. Error: ", GetLastError());
     }
}

// Calculate SuperTrend values (Simplified logic for clarity)
void calculate_supertrend(int atr_period, double atr_multiplier, string& trend, double& supertrend_val)
{
    double high[], low[], close[];
    if(CopyHigh(_Symbol, PERIOD_CURRENT, 1, 2, high) < 2 || 
       CopyLow(_Symbol, PERIOD_CURRENT, 1, 2, low) < 2 || 
       CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, close) < 2)
    {
        Print("Error copying price data for Supertrend calculation.");
        return;
    }

    double atr_buffer[];
    if(CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, atr_period), 0, 1, 1, atr_buffer) < 1)
    {
       Print("Error copying ATR buffer for period ", atr_period);
       return; 
    }
    double atr = atr_buffer[0];

    double basic_upper_band = (high[0] + low[0]) / 2.0 + atr_multiplier * atr;
    double basic_lower_band = (high[0] + low[0]) / 2.0 - atr_multiplier * atr;

    double final_upper_band = 0;
    double final_lower_band = 0;

    // Use previous supertrend value for continuity
    double prev_supertrend = supertrend_val; 
    string prev_trend = trend;

    if(prev_trend == "uptrend") {
        final_lower_band = MathMax(basic_lower_band, (prev_supertrend != 0) ? prev_supertrend : basic_lower_band);
    } else {
        final_lower_band = basic_lower_band;
    }

    if(prev_trend == "downtrend") {
        final_upper_band = MathMin(basic_upper_band, (prev_supertrend != 0) ? prev_supertrend : basic_upper_band);
    } else {
        final_upper_band = basic_upper_band;
    }

    // Determine trend and set supertrend value for the *current* completed bar (index 0 after shift)
    if(close[0] > ((prev_trend == "uptrend" && prev_supertrend != 0) ? prev_supertrend : final_upper_band)) // Compare with appropriate previous band
      {
         trend = "uptrend";
         supertrend_val = final_lower_band;
      }
    else if(close[0] < ((prev_trend == "downtrend" && prev_supertrend != 0) ? prev_supertrend : final_lower_band)) // Compare with appropriate previous band
      {
         trend = "downtrend";
         supertrend_val = final_upper_band;
      }
    else // No trend change, continue previous trend
      {
         if(prev_trend == "uptrend")
           {
            trend = "uptrend";
            supertrend_val = final_lower_band;
           }
         else if(prev_trend == "downtrend")
           {
            trend = "downtrend";
            supertrend_val = final_upper_band;
           }
         else // Initial state (or error recovery)
           {
              // Default guess based on close vs median
              if(close[0] > (high[0] + low[0]) / 2.0)
              {
                 trend = "uptrend";
                 supertrend_val = final_lower_band;
              }
              else
              {
                 trend = "downtrend";
                 supertrend_val = final_upper_band;
              }
           }
      }
    // Important: The calculated supertrend_val here is based on bar 1 data, 
    // representing the value *at the close* of bar 1 / *start* of bar 0.
}


// Get the current Moving Average value
double get_ma_value()
{
   double ma_buffer[1];
   int ma_handle = iMA(_Symbol, PERIOD_CURRENT, ma_period, 0, ma_method, ma_price);
   if(ma_handle == INVALID_HANDLE)
     {
      Print("Error getting MA handle. Code: ", GetLastError());
      return 0.0;
     }
   if(CopyBuffer(ma_handle, 0, 1, 1, ma_buffer) <= 0) // Get MA value for the last closed bar (index 1)
     {
      Print("Error copying MA buffer. Code: ", GetLastError());
      return 0.0;
     }
   return ma_buffer[0];
}

// Check Ichimoku Cloud position (based on last closed bar)
bool is_price_above_cloud()
{
   int ichimoku_handle = iIchimoku(_Symbol, PERIOD_CURRENT, tenkan_period, kijun_period, senkou_span_b_period);
   if(ichimoku_handle == INVALID_HANDLE)
     {
      Print("Error getting Ichimoku handle. Code: ", GetLastError());
      return false;
     }

   double senkou_span_a_buffer[1];
   double senkou_span_b_buffer[1];
   double close_buffer[1];

   // Get cloud values shifted 26 periods ahead, corresponding to the current price bar (index 1)
   // Note: Ichimoku lines are plotted shifted. Senkou A/B are plotted 26 periods ahead.
   // To compare current price (close[1]) with the cloud *at that time*, we need the cloud values from 26 bars ago.
   // However, standard interpretation often compares current price with the *current* cloud projection. Let's use the current cloud projection.
   // CopyBuffer indices for Ichimoku: 0=Tenkan, 1=Kijun, 2=SenkouA, 3=SenkouB, 4=Chikou
   // We need the *projected* cloud values for the *current* bar (index 0).
   // Senkou A and B are calculated based on past data but plotted ahead.
   // So, index 0 for buffer 2 and 3 gives the cloud projection for the *current* time.

   if(CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_span_a_buffer) < 1 ||
      CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_span_b_buffer) < 1 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close_buffer) < 1) // Use close of last completed bar
     {
      Print("Error copying Ichimoku or Close buffers. Code: ", GetLastError());
      return false;
     }

   double current_close = close_buffer[0];
   double cloud_top = MathMax(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);

   //Print("Ichimoku Check: Cloud top: ", cloud_top, " Current close[1]: ", current_close);

   return current_close > cloud_top;
}

bool is_price_below_cloud()
{
   int ichimoku_handle = iIchimoku(_Symbol, PERIOD_CURRENT, tenkan_period, kijun_period, senkou_span_b_period);
    if(ichimoku_handle == INVALID_HANDLE)
     {
      Print("Error getting Ichimoku handle. Code: ", GetLastError());
      return false;
     }

   double senkou_span_a_buffer[1];
   double senkou_span_b_buffer[1];
   double close_buffer[1];

   if(CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_span_a_buffer) < 1 ||
      CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_span_b_buffer) < 1 ||
      CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close_buffer) < 1) // Use close of last completed bar
     {
      Print("Error copying Ichimoku or Close buffers. Code: ", GetLastError());
      return false;
     }

   double current_close = close_buffer[0];
   double cloud_bottom = MathMin(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);

   //Print("Ichimoku Check: Cloud bottom: ", cloud_bottom, " Current close[1]: ", current_close);

   return current_close < cloud_bottom;
}

//+------------------------------------------------------------------+
//| Trailing Stop Management Function                                |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // We need the *current* Supertrend value (calculated at the start of the bar)
   // Ensure supertrend1 is valid
   if(supertrend1 == 0) return;

   // Iterate through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      // Select position by ticket
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue; // Skip if failed to get ticket

      // Get position info using CPositionInfo
      if(!position.SelectByTicket(ticket))
        {
         Print("Error selecting position #", ticket, " - ", GetLastError());
         continue;
        }

      // Check if it's our EA's position and on the correct symbol
      if(position.Magic() == MagicNumber && position.Symbol() == _Symbol)
        {
         double current_sl = position.StopLoss();
         double open_price = position.PriceOpen();
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double new_sl = 0;
         bool modify = false;

         // --- Trailing Logic for BUY positions ---
         if(position.PositionType() == POSITION_TYPE_BUY)
           {
            // Potential new SL is below the *current* uptrend Supertrend line
            // Requires trend1 to still be uptrend
            if(trend1 == "uptrend")
            {
                new_sl = NormalizeDouble(supertrend1 - TrailingStopBufferPoints * point, digits);

                // Conditions to move SL:
                // 1. New SL is higher than the current SL
                // 2. New SL is above the open price (locking profit)
                // 3. New SL respects the minimum stop distance from the *current* BID price
                if(new_sl > current_sl &&
                   new_sl > open_price &&
                   new_sl < current_bid - stopLevel * point) // Check against current bid for BUY
                  {
                     modify = true;
                  }
            }
           }
         // --- Trailing Logic for SELL positions ---
         else if(position.PositionType() == POSITION_TYPE_SELL)
           {
            // Potential new SL is above the *current* downtrend Supertrend line
            // Requires trend1 to still be downtrend
            if(trend1 == "downtrend")
            {
                new_sl = NormalizeDouble(supertrend1 + TrailingStopBufferPoints * point, digits);

                // Conditions to move SL:
                // 1. New SL is lower than the current SL
                // 2. New SL is below the open price (locking profit)
                // 3. New SL respects the minimum stop distance from the *current* ASK price
                if((new_sl < current_sl || current_sl == 0) && // Allow setting SL if it's 0
                   new_sl < open_price &&
                   new_sl > current_ask + stopLevel * point) // Check against current ask for SELL
                  {
                     modify = true;
                  }
            }
           }

         // --- Modify Position if needed ---
         if(modify)
           {
            if(trade.PositionModify(ticket, new_sl, position.TakeProfit()))
              {
               Print("Trailing Stop Loss modified for ticket ", ticket, ". New SL: ", NormalizeDouble(new_sl, digits));
              }
            else
              {
               Print("Error modifying Trailing Stop Loss for ticket ", ticket, ". Error code: ", GetLastError(), " Proposed SL: ", NormalizeDouble(new_sl, digits));
              }
           }
        }
     }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // --- Calculate Indicators on New Bar ---
   datetime currentCandleTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE); // Use SeriesInfoInteger for reliability

   if(currentCandleTime != lastCandleTime)
     {
      lastCandleTime = currentCandleTime;

      // Store previous trends *before* recalculating
      string prev_trend1 = trend1;
      string prev_trend2 = trend2;
      string prev_trend3 = trend3;
      
      // Calculate all three SuperTrends based on the *last closed bar* data
      calculate_supertrend(atr_period1, atr_multiplier1, trend1, supertrend1);
      calculate_supertrend(atr_period2, atr_multiplier2, trend2, supertrend2);
      calculate_supertrend(atr_period3, atr_multiplier3, trend3, supertrend3);

      // Check if trends have changed (optional, for logging)
      bool trend1_changed = (trend1 != prev_trend1 && prev_trend1 != "none");
      bool trend2_changed = (trend2 != prev_trend2 && prev_trend2 != "none");
      bool trend3_changed = (trend3 != prev_trend3 && prev_trend3 != "none");

      // Get indicator values based on the *last closed bar*
      double close_prev_bar = iClose(_Symbol, PERIOD_CURRENT, 1); // Price at the close of the previous bar
      double ma_value = get_ma_value(); // MA value from the previous bar
      bool above_cloud = is_price_above_cloud(); // Cloud position relative to previous bar's close
      bool below_cloud = is_price_below_cloud(); // Cloud position relative to previous bar's close

      // --- Entry Logic (Based on New Bar) ---
      // Check if any position for this EA already exists
      int ea_positions = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(position.SelectByIndex(i)) // Select position by index
           {
            if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
              {
               ea_positions++;
               break; // Found one, no need to check further if only one position is desired
              }
           }
        }

      // Only enter if no position exists for this EA on this symbol
      if(ea_positions == 0)
        {
         // Check if all three SuperTrends agree
         if(trend1 == trend2 && trend2 == trend3 && trend1 != "none")
           {
            // Execute trades if all conditions are met (using previous bar's data for conditions)
            // **Original Buy Logic (potentially counter-intuitive):** Uptrend, price *below* MA, price *below* cloud
            if(trend1 == "uptrend" && close_prev_bar < ma_value && below_cloud)
              {
               execute_buy();
               Print("BUY signal: All ST uptrend, Price[1]<MA, Price[1]<Cloud. ST1:", supertrend1, " MA:", ma_value, " Price[1]:", close_prev_bar);
              }
            // **Original Sell Logic (potentially counter-intuitive):** Downtrend, price *above* MA, price *above* cloud
            else if(trend1 == "downtrend" && close_prev_bar > ma_value && above_cloud)
              {
               execute_sell();
               Print("SELL signal: All ST downtrend, Price[1]>MA, Price[1]>Cloud. ST1:", supertrend1, " MA:", ma_value, " Price[1]:", close_prev_bar);
              }
           }
        }
        
       // --- Debug Print (Optional, on new bar) ---
       // Print("DEBUG New Bar - Time:", TimeToString(currentCandleTime));
       // Print("DEBUG ST1: ", trend1, " Val: ", NormalizeDouble(supertrend1, digits));
       // Print("DEBUG ST2: ", trend2, " Val: ", NormalizeDouble(supertrend2, digits));
       // Print("DEBUG ST3: ", trend3, " Val: ", NormalizeDouble(supertrend3, digits));
       // Print("DEBUG MA(", ma_period, "): ", NormalizeDouble(ma_value, digits));
       // Print("DEBUG Price[1]: ", NormalizeDouble(close_prev_bar, digits));
       // Print("DEBUG Above cloud: ", above_cloud ? "Yes" : "No", " Below cloud: ", below_cloud ? "Yes" : "No");

     } // End of New Bar Check

   // --- Manage Trailing Stop on Every Tick ---
   ManageTrailingStop();

}
//+------------------------------------------------------------------+