//+------------------------------------------------------------------+
//|                                                   4ChannelSR.mq5 |
//|        Copyright 2022-2024. Diamond Systems Corp. and Odiljon T. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+

//--- includes
#include <MqlSystems/4ChannelSR/4ChannelSR.mqh>

//--- enums
enum ENUM_CALC_PERIOD
{
   CALC_PERIOD_AUTO = 0,              // Auto
   CALC_PERIOD_D1 = FCHSR_PERIOD_D1,  // D1
   CALC_PERIOD_W1 = FCHSR_PERIOD_MN1, // W1
   CALC_PERIOD_MN = FCHSR_PERIOD_W1   // MN
};
enum ENUM_CONTINUING_LINES_AMOUNT
{
   CTN_LINE_1 = 1, // 1
   CTN_LINE_2 = 2, // 2
   CTN_LINE_3 = 3, // 3
   CTN_LINE_4 = 4  // 4
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
input int                          i_PeriodCnt = 5;                     // Period count
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
bool g_isInitChsr = false;
long g_chartId = 0;
int g_chsrTotal = 0;
int g_chsrIndex = 0;
string g_fchsrObjPrefix = "4ChannelSR_";
string g_objTooltip;
datetime g_zoneStart;
datetime g_zoneEnd;
double g_priceStepSR;
double g_priceHighSR;
double g_priceLowSR;
double g_priceHigh;
double g_priceLow;
bool g_isAdtLine;
double g_priceStepAdt;
double g_adtLineMinStep;
int g_adtLineAmount;
//---
ENUM_TIMEFRAMES g_calcPeriod;
//---
C4ChannelSR Chsr;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- check input parameters
   if (i_PeriodCnt < 1)
   {
      Print("Error: Enter the number of periods to calculate");
      return INIT_PARAMETERS_INCORRECT;
   }

   //--- calc period
   if (i_CalcPeriod == CALC_PERIOD_AUTO)
   {
      if (_Period >= PERIOD_W1)
         g_calcPeriod = PERIOD_D1;
      else if (_Period >= PERIOD_H4)
         g_calcPeriod = PERIOD_W1;
      else
         g_calcPeriod = PERIOD_D1;
   }
   else
      g_calcPeriod = (ENUM_TIMEFRAMES)i_CalcPeriod;

   //--- set object tooltip
   switch (g_calcPeriod)
   {
      case PERIOD_W1:  g_objTooltip = "W1"; break;
      case PERIOD_MN1: g_objTooltip = "MN"; break;
      default:         g_objTooltip = "D1"; break;
   }

   //--- Adt line
   g_isAdtLine = true;
   g_adtLineAmount = 0;
   if (i_AdtLineAmount == ADT_LINE_0)
      g_isAdtLine = false;
   else if (i_AdtLineAmount == ADT_LINE_A)
   {
      if (i_AdtLineDistanceMin > 0)
         g_adtLineMinStep = NormalizeDouble(i_AdtLineDistanceMin * _Point, _Digits);
      else
         g_isAdtLine = false;
   }
   else
      g_adtLineAmount = i_AdtLineAmount;

   //--- global variables
   g_chartId = ChartID();
   g_fchsrObjPrefix += g_objTooltip + "_";

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(g_chartId, g_fchsrObjPrefix);
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
      if (g_priceHigh < high[0] || g_priceLow > low[0])
         CreateContinuingLines(high[0], low[0]);

      return rates_total;
   }

   if (prev_calculated == 0)
   {
      g_chsrTotal = 0;
      g_chsrIndex = 0;
      ObjectsDeleteAll(g_chartId, g_fchsrObjPrefix);

      //--- initialize 4ChannelSR
      if (! g_isInitChsr)
      {
         g_isInitChsr = Chsr.Init(_Symbol, (ENUM_FCHSR_PERIODS)g_calcPeriod, i_PeriodCnt);
         if (! g_isInitChsr)
            return 0;
      }
   }

   if (! Chsr.Calculate())
      return prev_calculated;

   if (g_chsrTotal == Chsr.Total())
   {
      //--- checks and updates continuation lines
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      for (int i = limit - 1; i >= 0; i--)
      {
         if (g_priceHigh < high[i] || g_priceLow > low[i])
            CreateContinuingLines(high[i], low[i]);
      }

      return rates_total;
   }

   g_chsrTotal = Chsr.Total();
   ChannelSRInfo ChsrInfoCurr, ChsrInfoNext;

   for (; g_chsrIndex < g_chsrTotal; g_chsrIndex++)
   {
      ChsrInfoCurr = Chsr.At(g_chsrTotal - g_chsrIndex - 1);
      //---
      g_priceStepSR = ChsrInfoCurr.stepSR;
      g_zoneStart = ChsrInfoCurr.timeZoneStart;
      g_zoneEnd = ChsrInfoCurr.timeZoneEnd;

      //--- Additional line param
      if (g_isAdtLine)
      {
         if (i_AdtLineAmount == ADT_LINE_A)
         {
            int adtCnt = (int)MathFloor(g_priceStepSR / g_adtLineMinStep);
            if (adtCnt >= 2)
            {
               g_adtLineAmount = adtCnt - 1;
               g_priceStepAdt = g_priceStepSR / adtCnt;
            }
            else
            {
               g_adtLineAmount = 0;
               g_priceStepAdt = 0.0;
            }
         }
         else
            g_priceStepAdt = g_priceStepSR / (g_adtLineAmount + 1);
      }

      //--- Main lines
      CreateMainLines(ChsrInfoCurr.low);

      //--- Continuing lines
      g_priceHighSR = g_priceHigh = ChsrInfoCurr.low + (g_priceStepSR * 4);
      g_priceLowSR = g_priceLow = ChsrInfoCurr.low;

      if (i_CtnLineAmount > CTN_LINE_1)
      {
         g_priceHigh -= (i_CtnLineAmount - 1) * g_priceStepSR;
         g_priceLow += (i_CtnLineAmount - 1) * g_priceStepSR;
      }

      if (g_chsrIndex + 1 < g_chsrTotal)
      {
         ChsrInfoNext = Chsr.At(g_chsrIndex + 1);
         CreateContinuingLines(ChsrInfoNext.high, ChsrInfoNext.low);
      }
      else
      {
         double nextHigh = iHigh(_Symbol, g_calcPeriod, 0);
         double nextLow = iLow(_Symbol, g_calcPeriod, 0);

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
   for (int i = 0; i < 5; i++)
   {
      price = low + (g_priceStepSR * i);
      CreateLine("Main" + string(i - 2), g_zoneStart, g_zoneEnd, price, i_MainLineColor, i_MainLineStyle, i_MainLineWidth);

      if (g_adtLineAmount && i != 4)
         CreateAdditionalLines(price);
   }
}

//+------------------------------------------------------------------+
//| Create Continuing lines                                          |
//+------------------------------------------------------------------+
void CreateContinuingLines(double high, double low)
{
   while (g_priceHigh < high)
   {
      if (g_adtLineAmount)
         CreateAdditionalLines(g_priceHighSR);

      g_priceHigh += g_priceStepSR;
      g_priceHighSR += g_priceStepSR;

      CreateLine("Ctn", g_zoneStart, g_zoneEnd, g_priceHighSR, i_CtnLineColor, i_CtnLineStyle, i_CtnLineWidth);
   }

   while (g_priceLow > low)
   {
      g_priceLow -= g_priceStepSR;
      g_priceLowSR -= g_priceStepSR;

      CreateLine("Ctn", g_zoneStart, g_zoneEnd, g_priceLowSR, i_CtnLineColor, i_CtnLineStyle, i_CtnLineWidth);

      if (g_adtLineAmount)
         CreateAdditionalLines(g_priceLowSR);
   }
}

//+------------------------------------------------------------------+
//| Create Additional lines                                          |
//+------------------------------------------------------------------+
void CreateAdditionalLines(double priceLow)
{
   for (int i = 1; i <= g_adtLineAmount; i++)
      CreateLine("Adt", g_zoneStart, g_zoneEnd, priceLow + (g_priceStepAdt * i), i_AdtLineColor, i_AdtLineStyle, i_AdtLineWidth);
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
   string name = g_fchsrObjPrefix + objName + "_" + TimeToString(time1) + DoubleToString(price);

   ObjectCreate(g_chartId, name, OBJ_TREND, 0, time1, price, time2, price);
   ObjectSetString(g_chartId, name, OBJPROP_TOOLTIP, 0, g_objTooltip);
   ObjectSetInteger(g_chartId, name, OBJPROP_COLOR, lColor);
   ObjectSetInteger(g_chartId, name, OBJPROP_STYLE, lStyle);
   ObjectSetInteger(g_chartId, name, OBJPROP_WIDTH, lWidth);
   ObjectSetInteger(g_chartId, name, OBJPROP_BACK, false);
   ObjectSetInteger(g_chartId, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_chartId, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(g_chartId, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(g_chartId, name, OBJPROP_RAY_RIGHT, false);
#ifdef __MQL5__
   ObjectSetInteger(g_chartId, name, OBJPROP_RAY_LEFT, false);
#endif
}

//+------------------------------------------------------------------+
