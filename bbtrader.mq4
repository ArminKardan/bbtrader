#property strict

#define SOCKET_LIBRARY_USE_EVENTS
#include <socket-library-mt4-mt5.mqh>
#include <JAson.mqh>


string ExirnexSerial ="";

string   Hostname = "127.0.0.1";    // Server hostname or IP address
ushort   ServerPort = 13001;        // Server port

long delayCounter = 0;

CJAVal signalSourceFilter;
CJAVal json;
CJAVal messageJson;
CJAVal pendings;
CJAVal robots_ids_json;
CJAVal robots_enable_json;
CJAVal trades;
CJAVal trade;
CJAVal closed;
CJAVal signaled;
CJAVal current_uids;


CJAVal orders_to_close;

ClientSocket * glbClientSocket = NULL;


string Robots[];
string RobotsEnabled[];

int RobotCount = 0;

void ReconnectSocketTop()
{

   if (!glbClientSocket) {
      
      glbClientSocket = new ClientSocket(Hostname, ServerPort);
      
      if (glbClientSocket.IsSocketConnected()) {
      
        // Print("Client connection succeeded");
      } else {
         
        // Print("Client connection failed");
      }
  }
}


void ReconnectSocketButton()
{
   if (!glbClientSocket.IsSocketConnected()) {
     // Print("Client disconnected. Will retry.");
      delete glbClientSocket;
      glbClientSocket = NULL;
   }
}

int timerCounter = 0;

void ReReadRobotConfig()
{
  /*if(timerCounter < 10)
  {
    timerCounter++;
    return;
  }*/

  robots_ids_json.Deserialize("[]");
  robots_enable_json.Deserialize("[]");
  
  string enabled = text_reader("robots_enables.txt");
  string data = text_reader("robots_ids.txt");
  ushort u_sep=StringGetCharacter(";",0);
   
   
  RobotCount = StringSplit(data, u_sep,Robots);
  int cnt = StringSplit(enabled, u_sep,RobotsEnabled);
  
  if(cnt != RobotCount)
  {
    Print("Error in Robot Files");
  }
  if(cnt == RobotCount)
  {
     for(int i = 0; i < RobotCount; i++)
     {
       robots_ids_json.Add(StringToInteger(Robots[i]));
       robots_enable_json.Add(StringToInteger(RobotsEnabled[i]));
     }
  }
  timerCounter = 0;
}


string text_reader(string path)
{
    int f = FileOpen(path,FILE_READ|FILE_TXT);
    int i =0;
    string str = "";
    while( FileIsEnding(f) == False)
    {   
        str = str + FileReadString(f); 
    }
    FileClose(f);
    return str;
}




void OnInit() {
   
  pendings.Deserialize("[]");
  signaled.Deserialize("[]");
  signalSourceFilter.Deserialize("[]");
  
  Comment("Welcome to BBTrader Trade executer!");
  closed.Deserialize("{}");
  
  EventSetMillisecondTimer(1000);
  
  DailyProfitRefresh();
  TotalProfitRefresh();
                             
  INIT_SUCCEEDED;
}


void OnTimer()
{  
    ReReadRobotConfig();
    tim();
}

void OnDeinit(const int reason)
{
   if (glbClientSocket) {
      delete glbClientSocket;
      glbClientSocket = NULL;
   }
}

int counter = 0;
bool OrderExists(int magicNum)
{
  long mgnum = magicNum - 0;
  string mag = "";
   int TotalOrders = OrdersTotal();
   
   for(int i = 0; i < TotalOrders; i++)
   {
       if(OrderSelect(i,SELECT_BY_POS) == true)
       {
          if(OrderMagicNumber() == mgnum)
          {
             return true;
          }
       }
   }
   
   return false;
}

int initCounter = 0;

int side = 0;


int profit_updater_counter = 0;
double DailyProfitValue = 0;
double TotalProfitValue = 0;

double DailyProfitRefresh()
{
double profit = 0;
int i,hstTotal=OrdersHistoryTotal();
  for(i=0;i<hstTotal;i++)
    {
     if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==TRUE)
       {
         if(TimeToStr(TimeLocal(),TIME_DATE) == TimeToStr(OrderCloseTime(),TIME_DATE))
         {
            if(OrderType() == 0 || OrderType() == 1)
            {
               profit += OrderProfit() + OrderSwap() + OrderCommission();
            }
         }
       }
    }
   DailyProfitValue = profit;
   return(profit);
}


double TotalProfitRefresh()
{
  double profit = 0;
  int i,hstTotal=OrdersHistoryTotal();
  for(i=0;i<hstTotal;i++)
    {
     if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==TRUE)
       {
         if(OrderType() == 0 || OrderType() == 1)
         {
             profit += OrderProfit() + OrderSwap() + OrderCommission();
         }
       }
    }
   TotalProfitValue = profit;
   return(profit);
}



void tim()
{
   delayCounter = delayCounter + 1;
   ReconnectSocketTop();

   if(glbClientSocket.IsSocketConnected()) 
   {
      string message = glbClientSocket.Receive();
      messageJson.Deserialize(message);
      trades.Deserialize("[]");
      
      
      

         orders_to_close = messageJson["CloseTrades"];
         
         
         
         
         for(int o = 0; o < orders_to_close.Size(); o++)
         {
           string orderid = orders_to_close[o].ToStr();
           
           
           int TotalOrders = OrdersTotal();
           for(int t = 0; t < TotalOrders; t++)
           {
             if(OrderSelect(t,SELECT_BY_POS) == true)
             { 
               if(OrderTicket() == StringToInteger(orderid))
               {
                
                 MqlTick last_tick;
                 SymbolInfoTick(OrderSymbol(),last_tick);
                 int tickt = OrderTicket();
                 int ordtype = OrderType();
                 if(ordtype == OP_BUY)
                 {
                   Print("CLOSING X1");
                   OrderClose(tickt,OrderLots(),last_tick.bid,30);
                 }
                 else if(ordtype == OP_BUYLIMIT || ordtype == OP_BUYSTOP || ordtype == OP_SELLLIMIT || ordtype == OP_SELLSTOP)
                 {
                  Print("DELETING X");
                  OrderDelete(tickt);
                 }
                 else if(ordtype == OP_SELL)
                 {
                   Print("CLOSING X2");
                   OrderClose(tickt,OrderLots(),last_tick.ask,30);
                 }
               }   
             }
           }
         }
      
      
      
      

      if(messageJson["Valid"].ToBool() == True)
      {
            
            json = messageJson["Orders"];
            
            //Print("ORDER COUNT:"+ IntegerToString(json.Size()) );
            
            string mag = "";
            int TotalOrders = OrdersTotal();
            
            trades.Deserialize("[]");
            current_uids.Deserialize("[]");
            
               for(int t = 0; t < TotalOrders; t++)
               {
                  if(OrderSelect(t,SELECT_BY_POS) == true)
                  {  
                  
                     long my_uid = OrderMagicNumber() + 0;
                     trade.Deserialize("{}");
                     trade["ID"] = OrderTicket();
                     trade["MagicID"] = my_uid;
                     current_uids.Add(my_uid);
                     trade["Instrument"] = OrderSymbol();
                     trade["Lots"] = OrderLots();
                     trade["Profit"] = OrderProfit();
                     trade["Comment"] = OrderComment();
                     trade["Type"] = OrderType();
                     trade["TP"] = OrderTakeProfit();
                     trade["SL"] = OrderStopLoss();
                     trade["Entry"] = OrderOpenPrice();
                     trades.Add(trade);
                     
                     
                        
                     
                     bool found = false;
                     for(int i = 0; i < json.Size(); i++)
                     {
                        if(json[i]["UID"].ToInt() == my_uid)
                        {
                          double sl = NormalizeDouble(json[i]["Stoploss"].ToDbl(), Digits);
                          double tp = NormalizeDouble(json[i]["Takeprofit"].ToDbl(), Digits);
                          found = true;

                          if(MathAbs(sl - OrderStopLoss()) > 1*_Point || MathAbs(tp - OrderTakeProfit()) > 1*_Point)
                          {
                             Print("Order modifing 1");
                             OrderModify(OrderTicket(),OrderOpenPrice(), sl,tp, 0);
                          }
                        }
                     }
                     if(found == false)
                     {
                        string xd = IntegerToString(OrderMagicNumber() + 0);
                        int ordertype = OrderType();
                        
                        if(ordertype == OP_BUY)
                        {
                           if(!closed[xd])
                           {
                             closed[xd] = 1;
                           }
                           else
                           {
                              closed[xd] = closed[xd].ToInt() + 1;
                           }
                           if(closed[xd].ToInt() > 10)
                           {
                             if(StringFind(OrderComment() , "BB-") >=0)
                             {
                               Print("Order closing 1");
                               OrderClose(OrderTicket(),OrderLots(),Bid,30);
                               DailyProfitRefresh();
                               TotalProfitRefresh();
                             }
                           }
                        }
                        else if(ordertype == OP_SELL)
                        {
                           if(!closed[xd])
                           {
                             closed[xd] = 1;
                           }
                           else
                           {
                              closed[xd] = closed[xd].ToInt() + 1;
                           }
                           if(closed[xd].ToInt() > 10)
                           {

                              if(StringFind(OrderComment() , "BB-") >= 0)
                              {
                                 Print("Order closing 2");
                                 OrderClose(OrderTicket(),OrderLots(),Ask,30);
                                 DailyProfitRefresh();
                                 TotalProfitRefresh();
                              }
                           }
                        }
                        
                        if(ordertype == OP_BUYLIMIT || ordertype == OP_SELLLIMIT || ordertype == OP_BUYSTOP || ordertype == OP_SELLSTOP)
                        {
                           if(!closed[xd])
                           {
                             closed[xd] = 1;
                           }
                           else
                           {
                              closed[xd] = closed[xd].ToInt() + 1;
                           }
                           if(closed[xd].ToInt() > 10)
                           {
                             if(StringFind(OrderComment() , "BB-") >=0)
                             {
                               Print("Order closing 3");
                               OrderDelete(OrderTicket());
                             }
                           }
                        }
                        
                     }
                  }
            }
               
                
            
           // return;
            for(int i = 0; i < json.Size(); i++)
            {
            
               if(!OrderExists(json[i]["UID"].ToInt()))
               {
                 string symbol = json[i]["Symbol"].ToStr();
                 /*if(symbol == "EURUSD")
                 {
                   symbol = EURUSD;
                 }
                 else if(symbol == "XAUUSD")
                 {
                   symbol = XAUUSD;
                 }
                 else if(symbol == "USA30IDXUSD")
                 {
                   symbol = US30;
                 }
                 else if(symbol == "USATECHIDXUSD")
                 {
                   symbol = USTEC;
                 }*/
                 side = json[i]["Side"].ToInt();
                 //double vol = 0.01;
                 double vol = NormalizeDouble(json[i]["Volume"].ToDbl(),2);
                 double sl = NormalizeDouble(json[i]["Stoploss"].ToDbl(), Digits);
                 bool disablesl = json[i]["DisableLiveSL"].ToBool();
                 double tp = NormalizeDouble(json[i]["Takeprofit"].ToDbl(), Digits);
                 double risk = NormalizeDouble(json[i]["Risk"].ToDbl(), Digits);
                 string src = json[i]["Source"].ToStr();
                 double entryprice = NormalizeDouble(json[i]["EntryPrice"].ToDbl(), Digits);
                  
                  
                 if(!json[i]["UID"])
                 {
                  continue;
                 } 
                 
                 
                 long uuid = json[i]["UID"].ToInt();
                 

                 if(uuid <= 0)
                 {
                   Print("GHEYDESHO ZADAM!");
                   continue;
                 }
                 
                 
                 bool cont = false;
                 
                 
                 for(int j = 0; j < current_uids.Size(); j++)
                 {
                   if(current_uids[j].ToInt() == uuid)
                   {
                     cont = true; //it's already sent and exists!
                     break;
                   }
                 }
                 if(cont)
                 {
                  // Print("GHEYDESHO ZADAM222!");
                   continue;
                 }

                 for(int j = 0; j < pendings.Size(); j++)
                 {
                   if(pendings[j].ToInt() == uuid)
                   {
                     ///Print("Q:"+ IntegerToString(uuid));
                     cont = true;
                     break;
                   }
                 }
                 
                 if(cont)
                 {
                  // Print("GHEYDESHO ZADAM333!");
                   continue;
                 }
                 
      
                 pendings.Add(uuid);

                    if(side == OP_BUYLIMIT)
                    {
                        if(delayCounter > 10)
                        {
                        
                           bool fnd = false;
                           for(int sg = 0; sg < signaled.Size(); sg++)
                           {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                           }
                           
                           if(fnd == false)
                           {
                                if(OrderSend(symbol,OP_BUYLIMIT,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Bid) ,(int)(uuid - 0)))
                                {
                                   Print("BUY LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                   signaled.Add(uuid);
                                }
                                else
                                {
                                  Print("Buy limit error:"+ IntegerToString(uuid));
                                }
                           }
                        }
                    }    
                    else if(side == OP_SELLLIMIT)
                    {
                        if(delayCounter > 10)
                        {
                        
                           bool fnd = false;
                           for(int sg = 0; sg < signaled.Size(); sg++)
                           {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                           }
                           
                           if(fnd == false)
                           {
                                if(OrderSend(symbol,OP_SELLLIMIT,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Ask),(int)(uuid - 0)))
                                {
                                   Print("SELL LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                   signaled.Add(uuid);
                                }
                                else
                                {
                                  Print("SELL limit error:"+ IntegerToString(uuid));
                                }
                           }
                        }
                    }  





                    if(side == OP_BUYSTOP)
                    {
                        if(delayCounter > 10)
                        {
                        
                           bool fnd = false;
                           for(int sg = 0; sg < signaled.Size(); sg++)
                           {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                           }
                           
                           if(fnd == false)
                           {
                                if(OrderSend(symbol,OP_BUYSTOP,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Bid) ,(int)(uuid - 0)))
                                {
                                   Print("BUY STOP SUCCESSFUL:"+ IntegerToString(uuid));
                                   signaled.Add(uuid);
                                }
                                else
                                {
                                  Print("Buy Stop error:"+ IntegerToString(uuid));
                                }
                           }
                        }
                    }    
                    else if(side == OP_SELLSTOP)
                    {
                        if(delayCounter > 10)
                        {
                        
                           bool fnd = false;
                           for(int sg = 0; sg < signaled.Size(); sg++)
                           {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                           }
                           
                           if(fnd == false)
                           {
                                if(OrderSend(symbol,OP_SELLSTOP,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Ask),(int)(uuid - 0)))
                                {
                                   Print("SELL STOP SUCCESSFUL:"+ IntegerToString(uuid));
                                   signaled.Add(uuid);
                                }
                                else
                                {
                                  Print("SELL STOP error:"+ IntegerToString(uuid));
                                }
                           }
                        }
                    } 









                    else if(side == OP_BUY)
                    {
                        if(delayCounter > 10)
                        {
                        
                           bool fnd = false;
                           for(int sg = 0; sg < signaled.Size(); sg++)
                           {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                           }
                           
                           if(fnd == false)
                           {
                              if(tp < 0)
                              {
                                tp = 0;
                              }
                                 
                              
                             // entryprice = entryprice + (Ask - Bid) + 1*Point();
                              
                              if(sl < Bid)
                              {
                                 if(Ask > entryprice - (Ask - Bid) + 5*_Point)
                                 {
                                 
                                    if(disablesl)
                                    {
                                       if(OrderSend(symbol,OP_BUYLIMIT,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Bid) ,(int)(uuid - 0)))
                                       {
                                          Print("BUY LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                          signaled.Add(uuid);
                                       }
                                       else
                                       {
                                         Print("Buy limit error:"+ IntegerToString(uuid));
                                       }
                                    }
                                    else
                                    {
                                       if(OrderSend(symbol,OP_BUYLIMIT,vol,entryprice,0,sl,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Bid) ,(int)(uuid - 0)))
                                       {
                                          Print("BUY LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                          signaled.Add(uuid);
                                       }
                                       else
                                       {
                                         Print("Buy limit error:"+ IntegerToString(uuid));
                                       }
                                    
                                    }
                                    
                                 }
                                 else 
                                 {
                                    if(disablesl)
                                    {
                                       if(OrderSend(symbol,OP_BUY,vol,entryprice,100,0,tp,"BB-"+src ,(int)(uuid - 0)))
                                       {
                                          signaled.Add(uuid);
                                       }
                                       else
                                       {
                                         Print("Buy error:"+ IntegerToString(uuid));
                                       }
                                    }
                                    else
                                    {
                                       if(OrderSend(symbol,OP_BUY,vol,entryprice,100,sl,tp,"BB-"+src ,(int)(uuid - 0)))
                                       {
                                          signaled.Add(uuid);
                                       }
                                       else
                                       {
                                         Print("Buy error:"+ IntegerToString(uuid));
                                       }
                                    }
                                    
                                 }
                                 
                              }
                              else
                              {
                                 Print("BUYING RECEIVED BUT CANCELLED BECAUSE OF SL >> BID:"+IntegerToString(uuid));
                              }
                           }
                        }
                    }
                    else if(side == OP_SELL)
                    {
                       if(delayCounter > 10)
                       {
                          bool fnd = false;
                          for(int sg = 0; sg < signaled.Size(); sg++)
                          {
                              if(signaled[sg].ToInt() == uuid)
                              {
                                 fnd = true;
                                 break;
                              }
                          }
                          
                          Print("SENDING SELL...");
                           
                          if(fnd == false)
                          {
                             if(tp < 0)
                             {  
                               tp = 0;
                             }
                             Print("Order sending 2");
                             
                             
                             //entryprice = entryprice - (Ask - Bid) - 1*Point();;
                             
                             if(Ask < sl)
                             {
                                if(Bid < entryprice + (Ask - Bid) - 5*_Point)
                                {                                    
                                   if(disablesl)
                                   {          
                                      if(OrderSend(symbol,OP_SELLLIMIT,vol,entryprice,0,0,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Ask),(int)(uuid - 0)))
                                      {  
                                        Print("SELL LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                        signaled.Add(uuid);
                                      }
                                      else
                                      {
                                        Print("Sell limit error:"+ IntegerToString(uuid));
                                      }
                                   }
                                   else
                                   {          
                                      if(OrderSend(symbol,OP_SELLLIMIT,vol,entryprice,0,sl,tp,"BB-"+src+"-LIMIT-"+DoubleToStr(Ask),(int)(uuid - 0)))
                                      {  
                                        Print("SELL LIMIT SUCCESSFUL:"+ IntegerToString(uuid));
                                        signaled.Add(uuid);
                                      }
                                      else
                                      {
                                        Print("Sell limit error:"+ IntegerToString(uuid));
                                      }
                                   }
                                }
                                else 
                                {
                                   Print("Order sending 3");
                                   
                                   if(disablesl)
                                   {
                                     if(OrderSend(symbol,OP_SELL,vol,Bid,100,0,tp,"BB-"+src,(int)(uuid - 0)))
                                      {  
                                        signaled.Add(uuid);
                                      }
                                      else
                                      {
                                        Print("Sell error:"+ IntegerToString(uuid));
                                      }
                                   }
                                   else
                                   {
                                      if(OrderSend(symbol,OP_SELL,vol,Bid,100,sl,tp,"BB-"+src,(int)(uuid - 0)))
                                      {  
                                        signaled.Add(uuid);
                                      }
                                      else
                                      {
                                        Print("Sell error:"+ IntegerToString(uuid));
                                      }
                                   }
                                }
                            }
                            else
                            {
                              Print("SELLING RECEIVED BUT CANCELLED BECAUSE OF SL << ASK:"+ IntegerToString(uuid));
                            }
                          }
                       }
                    }
                 }
            }
      }
      else
      {
           int TotalOrders = OrdersTotal();
           trades.Deserialize("[]");
           for(int t = 0; t < TotalOrders; t++)
           {
              if(OrderSelect(t,SELECT_BY_POS) == true)
              {  
                 trade.Deserialize("{}");
                 trade["ID"] = OrderTicket();
                 trade["MagicID"] = OrderMagicNumber() + 0;
                 trade["Instrument"] = OrderSymbol();
                 trade["Lots"] = OrderLots();
                 trade["Profit"] = OrderProfit();
                 trade["Comment"] = OrderComment();
                 trade["Type"] = OrderType();
                 trade["TP"] = OrderTakeProfit();
                 trade["SL"] = OrderStopLoss();
                 trade["Entry"] = OrderOpenPrice();
                 trades.Add(trade);
   
              }
           }
      }

           
      json.Deserialize("{\"Robots\":[],\"RobotEnables\":[], \"Trades\":[]}");
      json["Query"] = true;
      json["AccNumber"] = AccountNumber();
      json["Balance"] = AccountBalance();
      json["AccServer"] = AccountServer();
      json["Company"] = AccountCompany();
      json["AccName"] = AccountName();
      json["Profit"] = AccountProfit();
      json["Currency"] = AccountCurrency();
      json["Margin"] = AccountMargin();
      json["StopOut"] = AccountStopoutLevel();
      json["DailyProfit"] = DailyProfitValue;
      json["TotalProfit"] = TotalProfitValue;
      json["Equity"] = AccountEquity();
      json["AccountName"] = AccountName();
      for(int i = 0; i < robots_ids_json.Size(); i++)
      {
         json["Robots"].Add(robots_ids_json[i]);
      }
      for(int i = 0; i < robots_enable_json.Size(); i++)
      {
         json["RobotEnables"].Add(robots_enable_json[i]);
      }
      for(int i = 0; i < trades.Size(); i++)
      {
         json["Trades"].Add(trades[i]);
      }
      

      string strMsg = json.Serialize(); 
      glbClientSocket.Send(strMsg);
      Sleep(100);
   } 
   

   ReconnectSocketButton();
   initCounter++;
}


void OnTick()
{
  
}