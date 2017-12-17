#include <Timer.h>
#include "message.h"

configuration SensorAppC {
}

implementation {
  components MainC, LedsC;

  components new ForwarderC(RecordMsg, ControlMsg);

  components ActiveMessageC as ControlC;
  components StartSplitControlC as StartControlC;

  StartControlC -> MainC.Boot;
  StartControlC.Control -> ControlC;

  components new AMSenderC(AM_RECORDMSG) as UpAMSenderC;
  components new AMReceiverC(AM_CONTROLMSG) as UpAMReceiverC;

  ForwarderC.UpPacket -> UpAMSenderC;
  ForwarderC.UpAMSend -> UpAMSenderC;
  ForwarderC.UpReceive -> UpAMReceiverC;
  ForwarderC.UpPacketAcks -> UpAMSenderC;

#ifdef DOWNSTREAM
  components new AMSenderC(AM_CONTROLMSG) as DownAMSenderC;
  components new AMReceiverC(AM_RECORDMSG) as DownAMReceiverC;

  ForwarderC.DownPacket -> DownAMSenderC;
  ForwarderC.DownAMSend -> DownAMSenderC;
  ForwarderC.DownReceive -> DownAMReceiverC;
  ForwarderC.DownPacketAcks -> DownAMSenderC;
#endif

  ForwarderC.Leds -> LedsC;

  components SensorC, new TimerMilliC() as Timer;
  SensorC.Control -> ControlC;
  SensorC.Timer -> Timer;
  SensorC.Forwarder -> ForwarderC;
}
