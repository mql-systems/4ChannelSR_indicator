//+------------------------------------------------------------------+
//|                                                   4ChannelSR.mq5 |
//|             Copyright 2022. Diamond Systems Corp. and Odiljon T. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022. Diamond Systems Corp. and Odiljon T."
#property link      "https://github.com/mql-systems"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 0;
#property indicator_plots 0;

//--- includes
#include <DS\4ChannelSR\4ChannelSR.mqh>

//--- enums
enum ENUM_CALC_PERIOD
{
   CALC_PERIOD_AUTO = 0,        // Auto
   CALC_PERIOD_D1 = PERIOD_D1,  // D1
   CALC_PERIOD_W1 = PERIOD_W1,  // W1
   CALC_PERIOD_MN = PERIOD_MN1, // MN
};

//--- inputs
input datetime                    i_StartDate = __DATE__-(86400*60); // Start date
input ENUM_CALC_PERIOD            i_CalcPeriod = CALC_PERIOD_AUTO;   // Calculate Period
input string                      i_s1 = "";                         // === Main lines ===
input color                       i_MainLineColor = clrRed;          // Color
input ENUM_LINE_STYLE             i_MainLineStyle = STYLE_SOLID;     // Style
input int                         i_MainLineWidth = 2;               // Width

//--- global variables
long     g_ChartId = 0;
int      g_ChsrTotal = 0;
int      g_ChsrIndex = 0;
string   g_4ChannelPrefix = "4ChannelSR_";
string   g_ObjTooltip;
//---
ENUM_CALC_PERIOD g_CalcPeriod;
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
         g_CalcPeriod = CALC_PERIOD_D1;
      else if (_Period >= PERIOD_H4)
         g_CalcPeriod = CALC_PERIOD_W1;
      else
         g_CalcPeriod = CALC_PERIOD_D1;
   }
   else
      g_CalcPeriod = i_CalcPeriod;
   
   //--- initialize 4ChannelSR
   int barCnt = iBarShift(_Symbol,(ENUM_TIMEFRAMES)g_CalcPeriod,i_StartDate,false);
   if (barCnt == -1)
   {
      Print("Error: The history for calculating the number of bars is not loaded");
      return INIT_FAILED;
   }
   if (! Chsr.Init(_Symbol, (ENUM_TIMEFRAMES)g_CalcPeriod, barCnt+1))
   {
      Print("Error: History not found");
      return INIT_FAILED;
   }
   
   //--- set object tooltip
   switch (g_CalcPeriod)
   {
      case CALC_PERIOD_W1: g_ObjTooltip = "W1"; break;
      case CALC_PERIOD_MN: g_ObjTooltip = "MN"; break;
      default:             g_ObjTooltip = "D1"; break;
   }
   
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
      return rates_total;
   if (! Chsr.Calculate())
      return prev_calculated;
   
   if (prev_calculated == 0)
   {
      g_ChsrTotal = 0;
      g_ChsrIndex = 0;
      ObjectsDeleteAll(g_ChartId, g_4ChannelPrefix);
   }
   else if (g_ChsrTotal == Chsr.Total())
      return rates_total;
   
   int i;
   g_ChsrTotal = Chsr.Total();
   ChannelSRInfo ChsrInfoCurr;
   
   for (; g_ChsrIndex<g_ChsrTotal; g_ChsrIndex++)
   {
      ChsrInfoCurr = Chsr.At(g_ChsrIndex);
      
      //--- Main SR
      for (i=0; i<5; i++)
      {
         CreateLine(
            "Main"+string(i-2),
            ChsrInfoCurr.timeZoneStart,
            ChsrInfoCurr.timeZoneEnd,
            ChsrInfoCurr.low+(ChsrInfoCurr.stepSR*i),
            i_MainLineColor,
            i_MainLineStyle,
            i_MainLineWidth
         );
      }
   }
   
   return rates_total;
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
   string name = g_4ChannelPrefix + objName + TimeToString(time1);
   
   ObjectCreate(g_ChartId, name, OBJ_TREND, 0, time1, price, time2, price);
   ObjectSetString(g_ChartId, name, OBJPROP_TOOLTIP, 0, g_ObjTooltip);
   ObjectSetInteger(g_ChartId, name, OBJPROP_COLOR, lColor);
   ObjectSetInteger(g_ChartId, name, OBJPROP_STYLE, lStyle);
   ObjectSetInteger(g_ChartId, name, OBJPROP_WIDTH, lWidth);
   ObjectSetInteger(g_ChartId, name, OBJPROP_BACK, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(g_ChartId, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
