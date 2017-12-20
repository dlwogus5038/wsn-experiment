#include <Timer.h>
#include "message.h"

configuration MasterAppC {
}

implementation {
  components MainC, LedsC;

  components ActiveMessageC as RadioControlC;

  components new AMSenderC(AM_ID) as RadioAMSenderC;
  components new AMReceiverC(AM_ID) as RadioAMReceiverC;

  components MasterC;

  MasterC -> MainC.Boot;
  MasterC.Leds -> LedsC;

  MasterC.RadioControl -> RadioControlC;


  MasterC.RadioPacket -> RadioAMSenderC;
  MasterC.RadioAMSend -> RadioAMSenderC;

#ifdef TASK_RECEIVE
  components SerialActiveMessageC as SerialControlC;

  components new SerialAMSenderC(AM_ID);
  components new SerialAMReceiverC(AM_ID);

  MasterC.SerialControl -> SerialControlC;

  MasterC.SerialPacket -> SerialAMSenderC;
  MasterC.SerialAMSend -> SerialAMSenderC;

  MasterC.RadioReceive -> RadioAMReceiverC;
#endif

#ifdef TASK_SEND
  components new TimerMilliC() as Timer;
  MasterC.Timer -> Timer;
#endif
}
