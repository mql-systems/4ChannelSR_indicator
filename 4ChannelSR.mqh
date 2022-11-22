//+------------------------------------------------------------------+
//|                                                   4ChannelSR.mq5 |
//|             Copyright 2022. Diamond Systems Corp. and Odiljon T. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+

//--- includes
#include <DS\4ChannelSR\4ChannelSR.mqh>

//--- enums
enum ENUM_CALC_PERIOD
{
   CALC_PERIOD_AUTO = 0,        // Auto
   CALC_PERIOD_D1 = PERIOD_D1,  // D1
   CALC_PERIOD_W1 = PERIOD_W1,  // W1
   CALC_PERIOD_MN = PERIOD_MN1  // MN
};
enum ENUM_CONTINUING_LINES_AMOUNT
{
   CTN_LINE_1 = 1,   // 1
   CTN_LINE_2 = 2,   // 2
   CTN_LINE_3 = 3,   // 3
   CTN_LINE_4 = 4    // 4
};
enum ENUM_ADT_LINES_AMOUNT
{
   ADT_LINE_0 = 0,   // false
   ADT_LINE_A = 100, // auto
   ADT_LINE_1 = 1,   // 1
   ADT_LINE_2 = 2,   // 2
   ADT_LINE_3 = 3,   // 3
   ADT_LINE_4 = 4    // 4
};

//--- inputs
input datetime                     i_StartDate = __DATE__-(86400*60);   // Start date
input ENUM_CALC_PERIOD             i_CalcPeriod = CALC_PERIOD_AUTO;     // Calculate Period
input string                       i_s1 = "";                           // === Main lines ===
input color                        i_MainLineColor = clrRed;            // Color
input ENUM_LINE_STYLE              i_MainLineStyle = STYLE_SOLID;       // Style
input int                          i_MainLineWidth = 2;                 // Width
input string                       i_s2 = "";                           // === Continuing lines ===
input ENUM_CONTINUING_LINES_AMOUNT i_CtnLineAmount = CTN_LINE_2;        // Amount
input color                        i_CtnLineColor = clrYellow;          // Color
input ENUM_LINE_STYLE              i_CtnLineStyle = STYLE_SOLID;        // Style
input int                          i_CtnLineWidth = 2;                  // Width
input string                       i_s3 = "";                           // === Additional lines ===
input ENUM_ADT_LINES_AMOUNT        i_AdtLineAmount = ADT_LINE_0;        // Amount
input int                          i_AdtLineDistanceMin = 100;          // Min distance (if Amount==auto)
input color                        i_AdtLineColor = clrPink;            // Color
input ENUM_LINE_STYLE              i_AdtLineStyle = STYLE_DASH;         // Style
input int                          i_AdtLineWidth = 1;                  // Width

//--- global variables
bool     g_IsInitChsr = false;
long     g_ChartId = 0;
int      g_ChsrTotal = 0;
int      g_ChsrIndex = 0;
string   g_4ChannelPrefix = "4ChannelSR_";
string   g_ObjTooltip;
datetime g_ZoneStart;
datetime g_ZoneEnd;
double   g_PriceStepSR;
double   g_PriceHighSR;
double   g_PriceLowSR;
double   g_PriceHigh;
double   g_PriceLow;
bool     g_IsAdtLine;
double   g_PriceStepAdt;
double   g_AdtLineMinStep;
int      g_AdtLineAmount;
//---
ENUM_TIMEFRAMES g_CalcPeriod;
//---
C4ChannelSR Chsr;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- check input parameters
   if (i_StartDate+86400 > TimeCurrent())
   {
      Print("Error: Start date entered incorrectly");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- calc period
   if (i_CalcPeriod == CALC_PERIOD_AUTO)
   {
      if (_Period >= PERIOD_W1)
         g_CalcPeriod = PERIOD_D1;
      else if (_Period >= PERIOD_H4)
         g_CalcPeriod = PERIOD_W1;
      else
         g_CalcPeriod = PERIOD_D1;
   }
   else
      g_CalcPeriod = (ENUM_TIMEFRAMES)i_CalcPeriod;
   
   //--- set object tooltip
   switch (g_CalcPeriod)
   {
      case PERIOD_W1:  g_ObjTooltip = "W1"; break;
      case PERIOD_MN1: g_ObjTooltip = "MN"; break;
      default:         g_ObjTooltip = "D1"; break;
   }
   
   //--- Adt line
   g_IsAdtLine = true;
   g_AdtLineAmount = 0;
   if (i_AdtLineAmount == ADT_LINE_0)
      g_IsAdtLine = false;
   else if (i_AdtLineAmount == ADT_LINE_A)
   {
      if (i_AdtLineDistanceMin > 0)
         g_AdtLineMinStep = NormalizeDouble(i_AdtLineDistanceMin * _Point, _Digits);
      else
         g_IsAdtLine = false;
   }
   else
      g_AdtLineAmount = i_AdtLineAmount;
   
   //--- global variables
   g_ChartId = ChartID();
   g_4ChannelPrefix += string(g_CalcPeriod)+"_";
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(g_ChartId, g_4ChannelPrefix);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int limit = rates_total - prev_calculated;
   if (limit == 0)
   {
      //--- checks and updates continuation lines
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      if (g_PriceHigh < high[0] || g_PriceLow > low[0])
         CreateContinuingLines(high[0], low[0]);
      
      return rates_total;
   }
   
   if (prev_calculated == 0)
   {
      g_ChsrTotal = 0;
      g_ChsrIndex = 0;
      ObjectsDeleteAll(g_ChartId, g_4ChannelPrefix);
      
      //--- initialize 4ChannelSR
      if (! g_IsInitChsr)
      {
         int barCnt = iBarShift(_Symbol,g_CalcPeriod,i_StartDate,false);
         if (barCnt == -1)
            return 0;
         g_IsInitChsr = Chsr.Init(_Symbol, g_CalcPeriod, barCnt+1);
         if (! g_IsInitChsr)
            return 0;
      }
   }
   
   if (! Chsr.Calculate())
      return prev_calculated;
   
   if (g_ChsrTotal == Chsr.Total())
   {
      //--- checks and updates continuation lines
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      for (int i=limit-1; i>=0; i--)
      {
         if (g_PriceHigh < high[i] || g_PriceLow > low[i])
            CreateContinuingLines(high[i], low[i]);
      }
      
      return rates_total;
   }
   
   g_ChsrTotal = Chsr.Total();
   ChannelSRInfo ChsrInfoCurr, ChsrInfoNext;
   
   for (; g_ChsrIndex<g_ChsrTotal; g_ChsrIndex++)
   {
      ChsrInfoCurr = Chsr.At(g_ChsrIndex);
      //---
      g_PriceStepSR = ChsrInfoCurr.stepSR;
      g_ZoneStart = ChsrInfoCurr.timeZoneStart;
      g_ZoneEnd = ChsrInfoCurr.timeZoneEnd;
      
      //--- Additional line param
      if (g_IsAdtLine)
      {
         if (i_AdtLineAmount == ADT_LINE_A)
         {
            int adtCnt = int(g_PriceStepSR / g_AdtLineMinStep);
            if (adtCnt >= 2)
            {
               g_AdtLineAmount = adtCnt - 1;
               g_PriceStepAdt = g_PriceStepSR / adtCnt;
            }
            else
            {
               g_AdtLineAmount = 0;
               g_PriceStepAdt = 0.0;
            }
         }
         else
            g_PriceStepAdt = g_PriceStepSR / (g_AdtLineAmount + 1);
      }

      //--- Main lines
      CreateMainLines(ChsrInfoCurr.low);
      
      //--- Continuing lines
      g_PriceHighSR = g_PriceHigh = ChsrInfoCurr.low+(g_PriceStepSR*4);
      g_PriceLowSR = g_PriceLow = ChsrInfoCurr.low;
      
      if (i_CtnLineAmount > CTN_LINE_1)
      {
         g_PriceHigh -= (i_CtnLineAmount-1)*g_PriceStepSR;
         g_PriceLow += (i_CtnLineAmount-1)*g_PriceStepSR;
      }
      
      if (g_ChsrIndex+1 < g_ChsrTotal)
      {
         ChsrInfoNext = Chsr.At(g_ChsrIndex+1);
         CreateContinuingLines(ChsrInfoNext.high, ChsrInfoNext.low);
      }
      else
      {
         double nextHigh = iHigh(_Symbol, g_CalcPeriod, 0);
         double nextLow = iLow(_Symbol, g_CalcPeriod, 0);
         
         if (nextHigh > 0 && nextLow > 0)
            CreateContinuingLines(nextHigh, nextLow);
      }
   }
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Create Main lines                                                |
//+------------------------------------------------------------------+
void CreateMainLines(double low)
{
   double price;
   for (int i=0; i<5; i++)
   {
      price = low+(g_PriceStepSR*i);
      CreateLine("Main"+string(i-2), g_ZoneStart, g_ZoneEnd, price, i_MainLineColor, i_MainLineStyle, i_MainLineWidth);
      
      if (g_AdtLineAmount && i!=4)
         CreateAdditionalLines(price);
   }
}

//+------------------------------------------------------------------+
//| Create Continuing lines                                          |
//+------------------------------------------------------------------+
void CreateContinuingLines(double high, double low)
{
   while (g_PriceHigh < high)
   {
      if (g_AdtLineAmount)
         CreateAdditionalLines(g_PriceHighSR);
      
      g_PriceHigh += g_PriceStepSR;
      g_PriceHighSR += g_PriceStepSR;
      
      CreateLine("Ctn", g_ZoneStart, g_ZoneEnd, g_PriceHighSR, i_CtnLineColor, i_CtnLineStyle, i_CtnLineWidth);
   }
   
   while (g_PriceLow > low)
   {
      g_PriceLow -= g_PriceStepSR;
      g_PriceLowSR -= g_PriceStepSR;
      
      CreateLine("Ctn", g_ZoneStart, g_ZoneEnd, g_PriceLowSR, i_CtnLineColor, i_CtnLineStyle, i_CtnLineWidth);
      
      if (g_AdtLineAmount)
         CreateAdditionalLines(g_PriceLowSR);
   }
}

//+------------------------------------------------------------------+
//| Create Additional lines                                          |
//+------------------------------------------------------------------+
void CreateAdditionalLines(double priceLow)
{
   for (int i=1; i<=g_AdtLineAmount; i++)
      CreateLine("Adt", g_ZoneStart, g_ZoneEnd, priceLow+(g_PriceStepAdt*i), i_AdtLineColor, i_AdtLineStyle, i_AdtLineWidth);
}

//+------------------------------------------------------------------+
//| Create line                                                      |
//+------------------------------------------------------------------+
void CreateLine(string objName,
                datetime time1,
                datetime time2,
                double price,
                color lColor,
                ENUM_LINE_STYLE lStyle,
                int lWidth)
{
   string name = g_4ChannelPrefix + objName + "_" + TimeToString(time1) + DoubleToString(price);
   
   ObjectCreate(g_ChartId, name, OBJ_TREND, 0, time1, price, time2, price);
   ObjectSetString(g_ChartId, name, OBJPROP_TOOLTIP, 0, g_ObjTooltip);
   ObjectSetInteger(g_ChartId, name, OBJPROP_COLOR, lColor);
   ObjectSetInteger(g_ChartId, name, OBJPROP_STYLE, lStyle);
   ObjectSetInteger(g_ChartId, name, OBJPROP_WIDTH, lWidth);
   ObjectSetInteger(g_ChartId, name, OBJPROP_BACK, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(g_ChartId, name, OBJPROP_RAY_RIGHT, false);
   #ifdef __MQL5__
   ObjectSetInteger(g_ChartId, name, OBJPROP_RAY_LEFT, false);
   #endif
}

//+------------------------------------------------------------------+
