#property copyright "Your Name"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#property strict

// Input parameters
input int    ATRPeriod      = 14;     // ATR Period
input double ATRMultiplier  = 1.5;    // ATR Multiplier for Stop Loss
input bool   EnableTrailing = true;   // Enable Trailing Stop

// Trading object
CTrade Trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Only process if trailing is enabled
    if(!EnableTrailing) return;
    
    // Process for buy and sell positions
    for(int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            // Ensure we're working with the current symbol
            if(PositionGetString(POSITION_SYMBOL) == Symbol())
            {
                // Calculate ATR
                double atr = iATR(Symbol(), Period(), ATRPeriod, 1);
                
                // Get current position details
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // Calculate new stop loss
                double newStopLoss = CalculateTrailingStop(currentPrice, atr, positionType);
                
                // Modify position if new stop loss is valid
                if(newStopLoss > 0)
                {
                    Trade.PositionModify(ticket, newStopLoss, 0);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop Calculation Function                               |
//+------------------------------------------------------------------+
double CalculateTrailingStop(double currentPrice, double atr, ENUM_POSITION_TYPE positionType)
{
    double stopLossBuffer = atr * ATRMultiplier;
    
    if(positionType == POSITION_TYPE_BUY)
    {
        return NormalizeDouble(currentPrice - stopLossBuffer, Digits());
    }
    else if(positionType == POSITION_TYPE_SELL)
    {
        return NormalizeDouble(currentPrice + stopLossBuffer, Digits());
    }
    
    return 0;
}