#include "message.h"

configuration SlaveAppC {
}

implementation {
  components MainC, LedsC;
  components TransportC, CalculateC;

  TransportC.Boot -> MainC;
  TransportC.Leds -> LedsC;

  CalculateC.Transport -> TransportC;

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
