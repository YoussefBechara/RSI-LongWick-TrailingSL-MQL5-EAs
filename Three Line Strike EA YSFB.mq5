#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

// Input parameters
input double Lot_size = 0.01;
input double sl_atr_multiplier = 2;
input double tp_atr_multiplier = 1;
input int atr_period = 14;
input int candlebody_avg_lookback = 20;

datetime lastCandleTime = 0;
double atrValue;

void execute_sell() {
    double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = entry - atrValue * tp_atr_multiplier;
    double sl = entry + atrValue * sl_atr_multiplier;
    trade.Sell(Lot_size, _Symbol, entry, sl, tp);
}

void execute_buy() {
    double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double tp = entry + atrValue * tp_atr_multiplier;
    double sl = entry - atrValue * sl_atr_multiplier;
    trade.Buy(Lot_size, _Symbol, entry, sl, tp);
}

int counter;
double first_candle_body = 0;
string candle_color = "None";
double previous_body_length = 0;

void OnTick() {
    datetime currentCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentCandleTime != lastCandleTime) {
        lastCandleTime = currentCandleTime;
        counter = 0; // Reset counter for each new candle

        int handleATR = iATR(_Symbol, PERIOD_CURRENT, atr_period);
        double atrBuffer[1];
        if (CopyBuffer(handleATR, 0, 0, 1, atrBuffer) != 1 || atrBuffer[0] <= 0) {
            return; // Check for valid ATR value
        }
        atrValue = atrBuffer[0];

        bool conditionsMet = true;
        for (int i = 4; i >= 1; i--) { // Check shifts 4,3,2,1 (closed candles)
            double open = iOpen(_Symbol, PERIOD_CURRENT, i);
            double close = iClose(_Symbol, PERIOD_CURRENT, i);
            double candle_body_length = MathAbs(open - close);

            if (i == 4) {
                double sum_candlebodies = 0;
                for (int j = i + 1; j <= i + candlebody_avg_lookback; j++) {
                    double curr_open = iOpen(_Symbol, PERIOD_CURRENT, j);
                    double curr_close = iClose(_Symbol, PERIOD_CURRENT, j);
                    sum_candlebodies += MathAbs(curr_open - curr_close);
                }
                double past_candlebody_avg = sum_candlebodies / candlebody_avg_lookback;
                if (past_candlebody_avg == 0 || (candle_body_length / past_candlebody_avg) < 0.25) {
                    conditionsMet = false;
                    break;
                }
                first_candle_body = candle_body_length;
                candle_color = (close > open) ? "Green" : "Red";
                previous_body_length = candle_body_length;
            } else if (i == 3 || i == 2) {
                if ((close > open && candle_color == "Red") || (close < open && candle_color == "Green")) {
                    conditionsMet = false;
                    break;
                }
                if (previous_body_length == 0 || (candle_body_length / previous_body_length) < 0.7) {
                    conditionsMet = false;
                    break;
                }
                previous_body_length = candle_body_length;
            } else if (i == 1) {
                if ((close > open && candle_color == "Green") || (close < open && candle_color == "Red")) {
                    conditionsMet = false;
                    break;
                }
                if (previous_body_length == 0 || (candle_body_length / previous_body_length) < 2) {
                    conditionsMet = false;
                    break;
                }
                previous_body_length = candle_body_length;
            }

            // Update counter based on current candle in the loop (i=4,3,2,1)
            if (close > open) counter++;
            else if (close < open) counter--;
        }

        if (conditionsMet) {
            if (counter == 4) execute_buy();
            else if (counter == -4) execute_sell();
        }
    }
}