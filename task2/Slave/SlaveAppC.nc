#include "message.h"

configuration SlaveAppC {
}

implementation {
  components MainC, LedsC;
  components TransportC, CalculateC;

  TransportC.Boot -> MainC;
  TransportC.Leds -> LedsC;

  CalculateC.Transport -> TransportC;
  CalculateC.Leds -> LedsC;

#if defined(TASK_MEDIAN) && !defined(MEDIAN_AFTER_SENDING)
  components Msp430DmaC;
  CalculateC.Msp430DmaChannel -> Msp430DmaC.Channel0;
#endif

  components new TimerMilliC() as Timer;
  components new TimerMilliC() as Timeout;

  TransportC.Timer -> Timer;
  TransportC.Timeout -> Timeout;

  components ActiveMessageC;

  components new AMSenderC(AM_ID);
  components new AMReceiverC(AM_ID);

  TransportC.Control -> ActiveMessageC;

  TransportC.Packet -> AMSenderC;
  TransportC.AMSend -> AMSenderC;
  TransportC.Receive -> AMReceiverC;
  TransportC.AMPacket -> AMSenderC;
  TransportC.PacketAcks -> AMSenderC;
}
