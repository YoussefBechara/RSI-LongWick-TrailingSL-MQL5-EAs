#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
CTrade trade;

// Input parameters
input double Lot_size = 0.01;
input int atr_period1 = 10;
input double atr_multiplier1 = 1.0;
input int atr_period2 = 12;
input double atr_multiplier2 = 3.0;
input int atr_period3 = 11;
input double atr_multiplier3 = 2.0;

// Moving Average parameters
input int ma_period = 200;     // Moving average period
input ENUM_MA_METHOD ma_method = MODE_SMA; // Moving average method (SMA, EMA, etc.)
input ENUM_APPLIED_PRICE ma_price = PRICE_CLOSE; // Applied price for MA calculation

// Ichimoku parameters
input int tenkan_period = 9;      // Tenkan-sen period (Conversion Line)
input int kijun_period = 26;      // Kijun-sen period (Base Line)
input int senkou_span_b_period = 52; // Senkou Span B period (2nd Leading Span)

// Global variables
datetime lastCandleTime = 0;
string trend1 = "none";
string trend2 = "none";
string trend3 = "none";
double supertrend1 = 0;
double supertrend2 = 0;
double supertrend3 = 0;

// Trade execution functions
void execute_sell() {
   double entry = SymbolInfoDouble(NULL, SYMBOL_BID);
   double tp = entry - 400*Point();
   double sl = entry + 400*Point();
   trade.Sell(Lot_size, NULL, entry, sl, tp);
   Print("SELL order executed. Entry: ", entry, " SL: ", sl, " TP: ", tp);
}

void execute_buy() {
   double entry = SymbolInfoDouble(NULL, SYMBOL_ASK);
   double tp = entry + 400*Point();
   double sl = entry - 400*Point();
   trade.Buy(Lot_size, NULL, entry, sl, tp);
   Print("BUY order executed. Entry: ", entry, " SL: ", sl, " TP: ", tp);
}

// Calculate SuperTrend values
void calculate_supertrend(int atr_period, double atr_multiplier, double &atr_value, double &up_band, double &down_band, string &trend, double &supertrend, string prev_trend) {
   // Calculate ATR
   int handleATR = iATR(NULL, PERIOD_CURRENT, atr_period);
   double atrBuffer[1];
   CopyBuffer(handleATR, 0, 0, 1, atrBuffer);
   atr_value = atrBuffer[0];
   
   // Calculate mid price, upper and lower bands
   double high = iHigh(NULL, PERIOD_CURRENT, 0);
   double low = iLow(NULL, PERIOD_CURRENT, 0);
   double mid_price = (high + low) / 2;
   up_band = mid_price - (atr_value * atr_multiplier);
   down_band = mid_price + (atr_value * atr_multiplier);
   
   // Get previous bands
   double prev_up_band = 0;
   double prev_down_band = 0;
   if (supertrend != 0) {
      prev_up_band = trend == "uptrend" ? supertrend : 0;
      prev_down_band = trend == "downtrend" ? supertrend : 0;
   }
   
   // Calculate current close price
   double close = iClose(NULL, PERIOD_CURRENT, 0);
   double prev_close = iClose(NULL, PERIOD_CURRENT, 1);
   
   // Update bands based on previous values
   if (prev_up_band > 0 && prev_close > prev_up_band) {
      up_band = MathMax(up_band, prev_up_band);
   }
   
   if (prev_down_band > 0 && prev_close < prev_down_band) {
      down_band = MathMin(down_band, prev_down_band);
   }
   
   // Determine trend
   if (close > supertrend && prev_trend != "uptrend") {
      trend = "uptrend";
      supertrend = up_band;
   } else if (close < supertrend && prev_trend != "downtrend") {
      trend = "downtrend";
      supertrend = down_band;
   } else if (prev_trend == "uptrend") {
      supertrend = up_band;
   } else if (prev_trend == "downtrend") {
      supertrend = down_band;
   } else {
      // Initialize
      if (close > mid_price) {
         trend = "uptrend";
         supertrend = up_band;
      } else {
         trend = "downtrend";
         supertrend = down_band;
      }
   }
}

// Get the current Moving Average value
double get_ma_value() {
   double ma_buffer[1];
   int ma_handle = iMA(NULL, PERIOD_CURRENT, ma_period, 0, ma_method, ma_price);
   CopyBuffer(ma_handle, 0, 0, 1, ma_buffer);
   return ma_buffer[0];
}

// Check Ichimoku Cloud position
bool is_price_above_cloud() {
   int ichimoku_handle = iIchimoku(NULL, PERIOD_CURRENT, tenkan_period, kijun_period, senkou_span_b_period);
   
   double senkou_span_a_buffer[1];
   double senkou_span_b_buffer[1];
   
   // Senkou Span A (Leading Span A)
   CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_span_a_buffer);
   // Senkou Span B (Leading Span B)
   CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_span_b_buffer);
   
   double current_price = iClose(NULL, PERIOD_CURRENT, 0);
   
   // Determine cloud top and bottom
   double cloud_top = MathMax(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);
   double cloud_bottom = MathMin(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);
   
   Print("Cloud top: ", cloud_top, " Cloud bottom: ", cloud_bottom, " Current price: ", current_price);
   
   return current_price > cloud_top;
}

bool is_price_below_cloud() {
   int ichimoku_handle = iIchimoku(NULL, PERIOD_CURRENT, tenkan_period, kijun_period, senkou_span_b_period);
   
   double senkou_span_a_buffer[1];
   double senkou_span_b_buffer[1];
   
   // Senkou Span A (Leading Span A)
   CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_span_a_buffer);
   // Senkou Span B (Leading Span B)
   CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_span_b_buffer);
   
   double current_price = iClose(NULL, PERIOD_CURRENT, 0);
   
   // Determine cloud top and bottom
   double cloud_top = MathMax(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);
   double cloud_bottom = MathMin(senkou_span_a_buffer[0], senkou_span_b_buffer[0]);
   
   Print("Cloud top: ", cloud_top, " Cloud bottom: ", cloud_bottom, " Current price: ", current_price);
   
   return current_price < cloud_bottom;
}

void OnTick() {
   datetime currentCandleTime = iTime(NULL, PERIOD_CURRENT, 0);
   if (currentCandleTime != lastCandleTime) {
      lastCandleTime = currentCandleTime;
      
      // Store previous trends
      string prev_trend1 = trend1;
      string prev_trend2 = trend2;
      string prev_trend3 = trend3;
      
      // Variables for SuperTrend calculation
      double atr_value1, up_band1, down_band1;
      double atr_value2, up_band2, down_band2;
      double atr_value3, up_band3, down_band3;
      
      // Calculate all three SuperTrends
      calculate_supertrend(atr_period1, atr_multiplier1, atr_value1, up_band1, down_band1, trend1, supertrend1, prev_trend1);
      calculate_supertrend(atr_period2, atr_multiplier2, atr_value2, up_band2, down_band2, trend2, supertrend2, prev_trend2);
      calculate_supertrend(atr_period3, atr_multiplier3, atr_value3, up_band3, down_band3, trend3, supertrend3, prev_trend3);
      
      // Check if trends have changed
      bool trend1_changed = (trend1 != prev_trend1);
      bool trend2_changed = (trend2 != prev_trend2);
      bool trend3_changed = (trend3 != prev_trend3);
      
      // Get current price and MA value
      double current_price = iClose(NULL, PERIOD_CURRENT, 0);
      double ma_value = get_ma_value();
      
      // Check cloud position
      bool above_cloud = is_price_above_cloud();
      bool below_cloud = is_price_below_cloud();
      
      // Debug information
      Print("Current price: ", current_price, " MA(", ma_period, "): ", ma_value);
      Print("Above cloud: ", above_cloud ? "Yes" : "No", " Below cloud: ", below_cloud ? "Yes" : "No");
      
      // Check if any trend has changed and all three give the same signal
      if ((trend1_changed || trend2_changed || trend3_changed) && 
          (trend1 == trend2 && trend2 == trend3)) {
         
         // Execute trades if all conditions are met
         if (trend1 == "uptrend" && current_price < ma_value && below_cloud) {
            execute_buy();
            Print("BUY signal: All three SuperTrends are in uptrend AND price is above MA(", ma_period, ") AND price is above Ichimoku Cloud");
         } else if (trend1 == "downtrend" && current_price > ma_value && above_cloud) {
            execute_sell();
            Print("SELL signal: All three SuperTrends are in downtrend AND price is below MA(", ma_period, ") AND price is below Ichimoku Cloud");
         }
      }
      
      // Debug information
      Print("SuperTrend 1: ", trend1, " Value: ", supertrend1);
      Print("SuperTrend 2: ", trend2, " Value: ", supertrend2);
      Print("SuperTrend 3: ", trend3, " Value: ", supertrend3);
   }
}