//+------------------------------------------------------------------+
//|                                       TwoCandlePatternEA_v2.mq5 |
//|                        Copyright 2025, Your Name/Company        |
//|                                        https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.10" // Version incremented
#property description "EA based on a two-candle pattern with risk management. Debug prints added."

#include <Trade\Trade.mqh> // Include the standard Trade library

//--- Input Parameters
input group           "Risk Management"
input bool            UseRiskPercent   = true;             // Use Risk % for Lot Size? (If false, uses FixedLotSize)
input double          RiskPercent      = 1.0;              // Risk percentage per trade (if UseRiskPercent is true)
input double          FixedLotSize     = 0.01;             // Fixed lot size (if UseRiskPercent is false)
input double          RiskRewardRatio  = 1.5;              // Take Profit based on Risk/Reward Ratio (e.g., 1.5 means TP distance is 1.5 * SL distance)
input int             StopLossBufferPips = 5;              // Additional buffer for Stop Loss in Pips
input int             MaxSlippagePips  = 3;                // Maximum allowed slippage in Pips
input ulong           MagicNumber      = 123457;           // Unique Magic Number for this EA (Changed slightly just in case)
input group           "Debugging"
input bool            EnableDebugPrints = true;            // Enable detailed print messages for debugging

//--- Global Variables
CTrade        trade;                     // Trading object
MqlRates      rates[];                   // Array to store price data
datetime      lastBarTime = 0;           // Time of the last processed bar
double        pointValue;                // Value of 1 point
int           digitsValue;               // Number of digits after the decimal point
string        eaName = "TwoCandlePatternEA_v2"; // EA Name for prints

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print(eaName, ": Initializing...");
   //--- Initialize Trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippagePips);
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Or ORDER_FILLING_IOC

   //--- Get symbol properties
   pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pointValue == 0) // Basic check if symbol info is available
     {
      Print(eaName, ": Error - Could not get SYMBOL_POINT for ", _Symbol);
      return(INIT_FAILED);
     }
   digitsValue = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //--- Check if RRR is valid
   if(RiskRewardRatio <= 0)
     {
      Print(eaName, ": Error - Risk Reward Ratio must be greater than 0.");
      return(INIT_FAILED);
     }

   //--- Check lot size settings
   if(!UseRiskPercent && FixedLotSize <= 0)
     {
      Print(eaName, ": Error - Fixed Lot Size must be positive if UseRiskPercent is false.");
      return(INIT_FAILED);
     }

   if(UseRiskPercent && RiskPercent <= 0)
     {
       Print(eaName, ": Error - Risk Percent must be positive if UseRiskPercent is true.");
       return(INIT_FAILED);
     }

   Print(eaName, " initialized successfully on ", _Symbol, ", TF: ", EnumToString(_Period));
   Print(eaName, ": Risk Mode: ", UseRiskPercent ? "Risk Percent (" + DoubleToString(RiskPercent, 2) + "%)" : "Fixed Lot (" + DoubleToString(FixedLotSize, 2) + ")");
   Print(eaName, ": RRR: 1:", DoubleToString(RiskRewardRatio, 2), ", SL Buffer: ", IntegerToString(StopLossBufferPips), " Pips, Slippage: ", IntegerToString(MaxSlippagePips), " Pips, Magic: ", IntegerToString(MagicNumber));

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print(eaName, ": Deinitialized. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if trading is allowed
   if(!IsTradingAllowed()) return; // Reason printed inside function

   //--- Check if enough bars are available
   if(Bars(_Symbol, _Period) < 3) return; // Wait for more history

   //--- Check for a new bar to avoid multiple trades on the same bar signal
   if(!IsNewBar()) return; // Process only once per bar

   if(EnableDebugPrints) Print(eaName, ": New Bar Detected at ", TimeToString(lastBarTime));

   //--- Get data for the last 2 completed bars + current bar
   //--- Array index: [0] is current forming bar, [1] is last closed bar, [2] is the one before that.
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3)
     {
      Print(eaName, ": Error copying rates: ", GetLastError());
      return;
     }
     
   //--- Check if a position for this symbol and magic number already exists
   if(PositionSelectByMagic(_Symbol, MagicNumber))
     {
      if(EnableDebugPrints) Print(eaName, ": Position already exists for Magic ", MagicNumber, ". Skipping check.");
      return; // Position already exists, do nothing
     }

   //--- Define candle properties based on CLOSED candles (index 1 and 2)
   //--- Index 1 = "Previous Candle" (most recently closed)
   //--- Index 2 = "Candle Before Previous"
   bool prevCandleIsGreen = rates[1].close > rates[1].open;
   bool prevCandleIsRed   = rates[1].close < rates[1].open;
   bool beforePrevCandleIsGreen = rates[2].close > rates[2].open;
   bool beforePrevCandleIsRed   = rates[2].close < rates[2].open;

   if(EnableDebugPrints)
     {
      Print(eaName, ": Checking Bar Time: ", TimeToString(rates[1].time));
      Print(eaName, ": Prev Candle[1]: O:", rates[1].open, " H:", rates[1].high, " L:", rates[1].low, " C:", rates[1].close, (prevCandleIsGreen ? " (Green)" : (prevCandleIsRed ? " (Red)" : " (Doji)")));
      Print(eaName, ": BeforePrev Candle[2]: O:", rates[2].open, " H:", rates[2].high, " L:", rates[2].low, " C:", rates[2].close, (beforePrevCandleIsGreen ? " (Green)" : (beforePrevCandleIsRed ? " (Red)" : " (Doji)")));
     }

   // --- === YOUR NEW CONDITIONS === ---

   //--- Sell Condition Check:
   //--- Previous candle [1] is Green
   //--- Candle before previous [2] is Red
   //--- Previous candle [1] High > Candle before previous [2] High
   if(prevCandleIsGreen && beforePrevCandleIsRed && rates[1].high > rates[2].high)
     {
      if(EnableDebugPrints) Print(eaName, ": SELL Condition Met.");
      ExecuteTrade(ORDER_TYPE_SELL, rates[1].high, rates[1].low); // Pass trigger candle hi/lo for SL calc base
      return; // Exit after attempting trade
     }

   //--- Buy Condition Check:
   //--- Previous candle [1] is Red
   //--- Candle before previous [2] is Green
   //--- Previous candle [1] Low < Candle before previous [2] Low
   if(prevCandleIsRed && beforePrevCandleIsGreen && rates[1].low < rates[2].low)
     {
      if(EnableDebugPrints) Print(eaName, ": BUY Condition Met.");
      ExecuteTrade(ORDER_TYPE_BUY, rates[1].high, rates[1].low); // Pass trigger candle hi/lo for SL calc base
      return; // Exit after attempting trade
     }

   if(EnableDebugPrints) Print(eaName, ": No trade conditions met for bar ", TimeToString(rates[1].time));

}

//+------------------------------------------------------------------+
//| Function to Execute Trades                                       |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double triggerCandleHigh, double triggerCandleLow)
{
   //--- Get current market prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask == 0 || bid == 0)
     {
      Print(eaName, ": Error getting Ask/Bid prices. Cannot execute trade.");
      return;
     }

   //--- Calculate Stop Loss Price level based on trigger candle and buffer
   double stopLossLevel = 0;
   double slBufferPrice = StopLossBufferPips * pointValue * 10.0; // Buffer in price units

   if(orderType == ORDER_TYPE_BUY)
     {
      stopLossLevel = triggerCandleLow - slBufferPrice;
     }
   else // ORDER_TYPE_SELL
     {
      stopLossLevel = triggerCandleHigh + slBufferPrice;
     }
   stopLossLevel = NormalizeDouble(stopLossLevel, digitsValue);


   //--- Calculate Stop Loss distance in points from the intended entry price
   double stopLossDistancePoints = 0;
   double entryPrice = 0; // Just for calculation clarity here

   if(orderType == ORDER_TYPE_BUY)
     {
      entryPrice = ask; // We intend to buy at Ask
      stopLossDistancePoints = (entryPrice - stopLossLevel) / pointValue;
     }
   else // ORDER_TYPE_SELL
     {
      entryPrice = bid; // We intend to sell at Bid
      stopLossDistancePoints = (stopLossLevel - entryPrice) / pointValue;
     }

   //--- Validate SL Distance (Important Check!)
   if(stopLossDistancePoints <= MaxSlippagePips * 10) // Use slippage as a minimum distance threshold too
     {
       Print(eaName, ": Error - Calculated Stop Loss distance (", DoubleToString(stopLossDistancePoints,1)," points) is too small or negative.");
       Print(eaName, ": Entry: ", DoubleToString(entryPrice, digitsValue), ", SL Level: ", DoubleToString(stopLossLevel, digitsValue));
       return;
     }

   //--- Calculate Take Profit Price
   double takeProfitPrice = 0;
   double takeProfitDistancePoints = stopLossDistancePoints * RiskRewardRatio;
   double takeProfitDistancePrice = takeProfitDistancePoints * pointValue;

   if(orderType == ORDER_TYPE_BUY)
     {
      takeProfitPrice = entryPrice + takeProfitDistancePrice;
     }
   else // ORDER_TYPE_SELL
     {
      takeProfitPrice = entryPrice - takeProfitDistancePrice;
     }
   takeProfitPrice = NormalizeDouble(takeProfitPrice, digitsValue);


   //--- Calculate Lot Size
   double lotSize = CalculateLotSize(stopLossDistancePoints);
   if(lotSize <= 0)
     {
      // Error message printed inside CalculateLotSize
      return;
     }

   //--- Place the Order
   string typeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   if(EnableDebugPrints)
    {
        Print(eaName, ": Attempting ", typeStr, " Order Details:");
        Print(eaName, ": Symbol: ", _Symbol);
        Print(eaName, ": Lot Size: ", DoubleToString(lotSize, 2));
        Print(eaName, ": Entry Price (approx): ", DoubleToString(entryPrice, digitsValue));
        Print(eaName, ": SL Price: ", DoubleToString(stopLossLevel, digitsValue), " (Dist: ", DoubleToString(stopLossDistancePoints, 1), " points)");
        Print(eaName, ": TP Price: ", DoubleToString(takeProfitPrice, digitsValue), " (Dist: ", DoubleToString(takeProfitDistancePoints, 1), " points)");
    }


   bool result = false;
   // Use stopLossLevel and takeProfitPrice calculated
   if(orderType == ORDER_TYPE_BUY)
     {
      // Market Buy: Price = 0, SL = stopLossLevel, TP = takeProfitPrice
      result = trade.Buy(lotSize, _Symbol, 0, stopLossLevel, takeProfitPrice, eaName + " Buy");
     }
   else // ORDER_TYPE_SELL
     {
      // Market Sell: Price = 0, SL = stopLossLevel, TP = takeProfitPrice
      result = trade.Sell(lotSize, _Symbol, 0, stopLossLevel, takeProfitPrice, eaName + " Sell");
     }

   //--- Check Result
   if(result)
     {
      Print(eaName, ": ", typeStr, " Order placed successfully. Ticket: ", trade.ResultDeal(), ", Order#: ", trade.ResultOrder());
     }
   else
     {
      Print(eaName, ": ", typeStr, " Order placement failed. Error code: ", trade.ResultRetcode(), ", Message: ", trade.ResultComment());
      // Common errors: 10013 (TRADE_RETCODE_INVALID_STOPS), 10015 (TRADE_RETCODE_INVALID_VOLUME), 10018 (TRADE_RETCODE_TOO_MANY_ORDERS)
     }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Settings                        |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   double lotSize = 0.0;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Ensure SL distance is valid before proceeding
   if(slDistancePoints <= 0)
     {
      Print(eaName, ": Error - Cannot calculate lot size with zero or negative SL distance (", DoubleToString(slDistancePoints,1)," points).");
      return 0.0;
     }

   if(UseRiskPercent)
     {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (RiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE); // Value of 1 tick for 1 lot contract
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);   // Size of 1 tick in price units (e.g., 0.00001 for EURUSD)

      if(tickValue <= 0 || tickSize <= 0)
        {
         Print(eaName, ": Error - Cannot calculate lot size due to invalid symbol info. TickValue:", tickValue, ", TickSize:", tickSize);
         return(0.0); // Return 0 to indicate failure
        }

      // Calculate value per point for 1 full lot
      double valuePerPoint = tickValue / tickSize * pointValue;

      if(valuePerPoint <= 0)
       {
           Print(eaName, ": Error calculating value per point. TickValue: ", tickValue, " TickSize: ", tickSize, " Point: ", pointValue);
           return(0.0);
       }

       if(slDistancePoints * valuePerPoint <= 0) // Prevent division by zero or negative
       {
            Print(eaName, ": Error - Invalid risk calculation denominator (SL Points * ValuePerPoint <= 0). SL Points: ", slDistancePoints, " ValuePerPoint: ", valuePerPoint);
            return 0.0;
       }

      lotSize = riskAmount / (slDistancePoints * valuePerPoint);

      if(EnableDebugPrints) Print(eaName, ": Risk Calc: Balance=", accountBalance, ", Risk%=", RiskPercent, ", RiskAmt=", riskAmount, ", SLPoints=", slDistancePoints, ", ValPerPoint=", valuePerPoint, ", RawLot=", lotSize);

     }
   else // Use Fixed Lot Size
     {
      lotSize = FixedLotSize;
      if(EnableDebugPrints) Print(eaName, ": Using Fixed Lot Size: ", lotSize);
     }

   //--- Normalize the lot size according to symbol rules
   lotSize = MathFloor(lotSize / lotStep) * lotStep; // Adjust down to nearest lot step

   //--- Check against min/max lot sizes
   if(lotSize < minLot)
     {
      if(EnableDebugPrints) Print(eaName, ": Calculated lot size (", DoubleToString(lotSize,8) ,") is less than minimum allowed (", minLot ,"). Adjusting.");
      // If risk % calc resulted in < minLot, maybe don't trade? Or use minLot if balance allows? For now, use minLot if > 0 after normalization.
       if (lotSize > 0) {
           // It was positive but below min, let's see if we used fixed lot. If fixed lot is below min, that's an input error.
           if (!UseRiskPercent && FixedLotSize < minLot) {
                Print(eaName, ": Warning - FixedLotSize input (", FixedLotSize, ") is below symbol minimum (", minLot, "). Cannot trade.");
                return 0.0; // Cannot place trade with invalid fixed lot
           }
           // If using risk % and it resulted in < minLot, use minLot only if affordable
           // For simplicity now, we'll just set it to minLot and let the broker reject if margin isn't enough
           lotSize = minLot;
           Print(eaName, ": Setting lot size to minimum allowed: ", lotSize);
       } else {
            Print(eaName, ": Calculated lot size is zero or negative after normalization. Cannot trade.");
            return 0.0; // Cannot place trade if lot size is effectively zero
       }
     }
     
   if(lotSize > maxLot)
     {
       Print(eaName, ": Calculated lot size (", DoubleToString(lotSize,8) ,") is greater than maximum allowed (", maxLot ,"). Setting to maximum.");
       lotSize = maxLot;
     }

   // Final check if lot size is valid after all adjustments
   if (lotSize <= 0 || lotSize < minLot)
     {
      Print(eaName, ": Error - Final lot size (", DoubleToString(lotSize, 8), ") is invalid or below minimum (", minLot, ").");
      return(0.0);
     }

   if(EnableDebugPrints) Print(eaName, ": Final Validated Lot Size: ", DoubleToString(lotSize, 2));
   return(lotSize);
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                    |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   bool mqlTrade = MQLInfoInteger(MQL_TRADE_ALLOWED);
   bool accountTrade = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED);
   bool terminalTrade = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);

   if(!mqlTrade || !accountTrade || !terminalTrade)
    {
     // Print only if state changes or on first check
     static bool printed = false;
     if(!printed)
     {
       Print(eaName, ": Trading is not allowed! MQL=", mqlTrade, ", Account=", accountTrade, ", Terminal=", terminalTrade);
       printed = true;
     }
     return(false);
    }
   // Potentially add more checks (e.g., time filters) here if needed
   return(true);
}

//+------------------------------------------------------------------+
//| Check for a new bar                                              |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentTime = iTime(_Symbol, _Period, 0); // Time of the currently forming bar
   // Check if the time of the current bar is different from the last time we processed a bar
   if(currentTime != lastBarTime)
     {
      lastBarTime = currentTime; // Update the last processed bar time
      return(true); // It's a new bar
     }
   return(false); // Still the same bar
}

//+------------------------------------------------------------------+
//| Selects a position by magic number and symbol                  |
//+------------------------------------------------------------------+
bool PositionSelectByMagic(string symbol, ulong magic)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      // Attempt to select the position by its index to retrieve its properties
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket > 0) // Check if PositionGetTicket returned a valid ticket
        {
         // Check if symbol and magic number match the selected position's properties
         if(PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magic)
           {
            // Position found for this symbol and magic number
            // We don't need PositionSelect() here because PositionGetTicket() effectively selects it for subsequent PositionGet* calls
            return(true);
           }
        }
      else
        {
         // Handle potential error in PositionGetTicket if needed, though unlikely in a simple loop
         // Print(eaName, ": Error getting position ticket for index ", i, " - Error code: ", GetLastError());
        }
     }
   // No position found with the specified symbol and magic number
   return(false);
  }
//+------------------------------------------------------------------+