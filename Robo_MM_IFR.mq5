//+------------------------------------------------------------------+
//|                                                  Robo_MM_IFR.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
//---

#include <Trade\Trade.mqh>

enum calcular_
  {
   calcular_s = 1,   //Sim
   calcular_n = 0    //Não
  };

enum usar_meta_
  {
   meta_s = 1,   //Sim
   meta_n = 0    //Não
  };

sinput   string s1;                                            //--- Médias Móveis ---
input    int mm_rapida_periodo            = 9;                 // Periodo Média Rápida
input    int mm_lenta_periodo             = 21;                // Periodo Média Lenta
input    ENUM_TIMEFRAMES mm_tempo_grafico = PERIOD_CURRENT;    // Tempo Gráfico
input    ENUM_MA_METHOD mm_metodo         = MODE_EMA;          // Método
input    ENUM_APPLIED_PRICE mm_preco      = PRICE_CLOSE;       // Preço Aplicado

sinput   string s2;                                            //--- Config. Entrada e Saída ---
input    double num_lotes                 = 0.01;              // Número de Lotes
input    double TK                        = 200;               // Take Profit
input    double SL                        = 200;               // Stop Loss

sinput   string s3;                                            //--- Valor para Mover o SL ---
input    int InputDistancia               = 20;                // Distância em Pontos
input    int InputCaminhar                = 5;                // Pontos do SL após Breakeven
input    int InputDistanciaAposBreakEven  = 50;                // Distância do SL após Breakeven
input    calcular_ CalcularSpread         = calcular_s;        // Calcular Spread

sinput   string s4;                                            //--- Meta Diária ---
input    usar_meta_ UsarMeta              = meta_s;            // Usar Meta de Ganho
input    double meta_de_ganho             = 10.00;              //Meta de Ganho


//+------------------------------------------------------------------+
//| Variáveis para os indicadores                                    |
//+------------------------------------------------------------------+
//---Médias Móveis
// RÁPIDA - Menor período
int mm_rapida_Handle;      // Handle controlador de média móveil rápida
double mm_rapida_Buffer[]; // Buffer para armazenamento de dados da média móvel rápida

// LENTA - Maior período
int mm_lenta_Handle;      // Handle controlador de média móveil lenta
double mm_lenta_Buffer[]; // Buffer para armazenamento de dados da média móvel lenta

//--- IFR
int ifr_Handle;      // Handle controlador para IFR
double ifr_Buffer[]; // Buffer para armazenamento de dados do IFR

//+------------------------------------------------------------------+
//| Variáveis para as Funções                                        |
//+------------------------------------------------------------------+

int magic_number = 031109; // Número mágico do Robô

MqlRates velas[];          // Variável para armazenar velas
MqlTick tick;              // Variável para armazenar ticks
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ChartSetInteger(0, CHART_SHOW_GRID, false);
//---
   mm_rapida_Handle = iMA(_Symbol, mm_tempo_grafico, mm_rapida_periodo, 0, mm_metodo, mm_preco);
   mm_lenta_Handle = iMA(_Symbol, mm_tempo_grafico, mm_lenta_periodo, 0, mm_metodo, mm_preco);

   if(mm_rapida_Handle < 0 || mm_lenta_Handle < 0)
     {
      Alert("Erro ao tentar criar Handles para o indicador - erro: ", GetLastError(), "!");
      return (-1);
     }

   CopyRates(_Symbol, _Period, 0, 4, velas);
   ArraySetAsSeries(velas, true);

// Para adicionar no Gráfico o indicador
   ChartIndicatorAdd(0, 0, mm_rapida_Handle);
   ChartIndicatorAdd(0, 0, mm_lenta_Handle);
//ChartIndicatorAdd(0, 1, ifr_Handle);
//---

//---
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   IndicatorRelease(mm_rapida_Handle);
   IndicatorRelease(mm_lenta_Handle);
  }

//+------------------------------------------------------------------+
//| Função para mover o stoploss                                     |
//+------------------------------------------------------------------+
void MoverStopLoss()
  {

   for(int i = PositionsTotal(); i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol)
        {
         //=== COMPRA ====//
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
           {
            if(PositionGetDouble(POSITION_PRICE_CURRENT) > PositionGetDouble(POSITION_PRICE_OPEN) + (InputDistancia * _Point))
              {
               if(PositionGetDouble(POSITION_SL) < PositionGetDouble(POSITION_PRICE_OPEN))
                 {
                  if(CalcularSpread == false)
                    {
                     trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_PRICE_OPEN), 0);
                    }
                  else
                    {
                     trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_PRICE_OPEN) + (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)*_Point), 0);
                    }
                 }
               else
                 {
                  if(PositionGetDouble(POSITION_PRICE_CURRENT) > PositionGetDouble(POSITION_SL) + (InputDistanciaAposBreakEven * _Point))
                    {
                     trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_SL) + (InputCaminhar * _Point), 0);
                    }
                 }
              }
           }

         //=== VENDA ====//
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
           {
            if(PositionGetDouble(POSITION_PRICE_CURRENT) < PositionGetDouble(POSITION_PRICE_OPEN) - (InputDistancia * _Point))
              {
               if(PositionGetDouble(POSITION_SL) > PositionGetDouble(POSITION_PRICE_OPEN))
                 {
                  trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_PRICE_OPEN), 0);
                 }
               else
                 {
                  if(PositionGetDouble(POSITION_PRICE_CURRENT) < PositionGetDouble(POSITION_SL) - (InputDistanciaAposBreakEven * _Point))
                    {
                     trade.PositionModify(PositionGetTicket(i), PositionGetDouble(POSITION_SL) - (InputCaminhar * _Point), 0);
                    }
                 }
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

//---

   double lucroDiario = CalculaLucroDiario();

// Copiar um vetor de dados tamanho três para o vetor mm_Buffer
   CopyBuffer(mm_rapida_Handle, 0, 0, 4, mm_rapida_Buffer);
   CopyBuffer(mm_lenta_Handle, 0, 0, 4, mm_lenta_Buffer);

//--- Alimentar Buffers das velas com dados
   CopyRates(_Symbol, _Period, 0, 4, velas);
   ArraySetAsSeries(velas, true);

//--- Ordenar o vetor de dados;
   ArraySetAsSeries(mm_rapida_Buffer, true);
   ArraySetAsSeries(mm_lenta_Buffer, true);

//--- Alimentar com dados variável de tick
   SymbolInfoTick(_Symbol, tick);

//--- LÓGICA PARA ATIVAR COMPRA
   bool compra_mm_cros = mm_rapida_Buffer[0] > mm_lenta_Buffer[0] &&
                         mm_rapida_Buffer[2] < mm_lenta_Buffer[2];

//--- LÓGICA PARA ATIVAR VENDA
   bool venda_mm_cros = mm_lenta_Buffer[0] > mm_rapida_Buffer[0] &&
                        mm_lenta_Buffer[2] < mm_rapida_Buffer[2];

//---
   bool Comprar = false;
   bool Vender  = false;


//---
   if(lucroDiario >= meta_de_ganho)
     {

      Print("Meta diária atingida. Lucro: ", lucroDiario);
      ExpertRemove();

     }

//---

   Comprar = compra_mm_cros;
   Vender  = venda_mm_cros;


   bool temosNovaVela = HaNovaVela();

   if(temosNovaVela)
     {
      if(Comprar && PositionSelect(_Symbol) == false)
        {
         desenharLinhaVertical("Compra", velas[2].time, clrBlue);
         CompraAMercado();
        }
      if(Vender && PositionSelect(_Symbol) == false)
        {
         desenharLinhaVertical("Venda", velas[2].time, clrRed);
         VendaAMercado();
        }
     }


   MoverStopLoss();

  }

//+------------------------------------------------------------------+
//| FUNÇÃO PARA AUXILIAR NA VISUALIZAÇÃO DA ESTRATÉGIA               |
//+------------------------------------------------------------------+
void desenharLinhaVertical(string nome, datetime dt, color cor = clrBlueViolet)
  {
   ObjectDelete(0, nome);
   ObjectCreate(0, nome, OBJ_VLINE, 0, dt, 0);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
  }

//+------------------------------------------------------------------+
//| FUNÇÃO PARA ENVIO DE ORDEM                                       |
//+------------------------------------------------------------------+

//---Função Para Compra
void CompraAMercado()
  {
   MqlTradeRequest requisicao;
   MqlTradeResult resposta;

   ZeroMemory(requisicao);
   ZeroMemory(resposta);

//--- Caracteristicas da ordem de compra
   requisicao.action = TRADE_ACTION_DEAL;
   requisicao.magic = magic_number;
   requisicao.symbol = _Symbol;
   requisicao.volume = num_lotes;
   requisicao.price = NormalizeDouble(tick.ask, _Digits);
   requisicao.sl = NormalizeDouble(tick.ask - SL * _Point, _Digits);
//requisicao.tp = NormalizeDouble(tick.ask + TK * _Point, _Digits);
   requisicao.deviation = 0;
   requisicao.type = ORDER_TYPE_BUY;
   requisicao.type_filling = ORDER_FILLING_FOK;

//---
   OrderSend(requisicao, resposta);
//---
   if(resposta.retcode == 10008 || resposta.retcode == 10009)
     {
      Print("Ordem de Compra executado com sucesso!");
     }
   else
     {
      Print("Erro ao enviar Ordem Compra. Erro = ", GetLastError());
      ResetLastError();
     }
  }

//---Funão Para Venda
void VendaAMercado()
  {
   MqlTradeRequest requisicao;
   MqlTradeResult resposta;

   ZeroMemory(requisicao);
   ZeroMemory(resposta);

//--- Caracteristica da ordem de venda
   requisicao.action = TRADE_ACTION_DEAL;
   requisicao.magic = magic_number;
   requisicao.symbol = _Symbol;
   requisicao.volume = num_lotes;
   requisicao.price = NormalizeDouble(tick.bid, _Digits);
   requisicao.sl = NormalizeDouble(tick.bid + SL * _Point, _Digits);
//requisicao.tp = NormalizeDouble(tick.bid - TK * _Point, _Digits);
   requisicao.deviation = 0;
   requisicao.type = ORDER_TYPE_SELL;
   requisicao.type_filling = ORDER_FILLING_FOK;

//---
   OrderSend(requisicao, resposta);
//---

   if(resposta.retcode == 10008 || resposta.retcode == 10009)
     {
      Print("Ordem de Venda executado com sucesso!");
     }
   else
     {
      Print("Erro ao enviar Ordem Venda. Erro = ", GetLastError());
      ResetLastError();
     }
  }
//+------------------------------------------------------------------+
//| FECHAR TODAS AS POSIÇÕES                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
// Obtenha o número total de posições abertas
   int totalPositions = PositionsTotal();

// VERIFICAR SE HÁ POSIÇÕES ABERTAS
   if(totalPositions > 0)
     {

      // Loop através de todas as posições
      for(int i = totalPositions - 1; i >= 0; i--)
        {
         // Obtem o tick da posição
         ulong positionTicket = PositionGetTicket(i);

         // Feche a posição
         trade.PositionClose(positionTicket);
        }

     }
   else
     {

      Print("Não há posições abertas!");

     }

  }

//+------------------------------------------------------------------+
//| FUNÇÃO PARA NOVA VELA                                            |
//+------------------------------------------------------------------+
bool HaNovaVela()
  {
//--- Memoriza o tempo de abertura da última vela numa variáveol
   static datetime last_time = 0;
//--- Tempo Atual
   datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);

//--- Se for a primeira chamada da função:
   if(last_time == 0)
     {
      //--- Atribuir o valor temporal e sair
      last_time = lastbar_time;
      return (false);
     }

   if(last_time != lastbar_time)
     {
      last_time = lastbar_time;
      return (true);
     }
   return (false);
  }

//+------------------------------------------------------------------+
//| FUNÇÃO PARA CALCULAR O LUCRO DIÁRIO                              |
//+------------------------------------------------------------------+
double CalculaLucroDiario()
  {
   double lucroDiario = 0.0;
   datetime inicioDoDia = iTime(_Symbol, PERIOD_D1, 0);

   if(HistorySelect(inicioDoDia, TimeCurrent()))
     {
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
           {

            lucroDiario += HistoryDealGetDouble(ticket, DEAL_PROFIT);

           }

        }
     }

   return lucroDiario;
  }
//+------------------------------------------------------------------+
