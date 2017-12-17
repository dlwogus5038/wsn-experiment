#include <Timer.h>
#include "message.h"

configuration BaseStationAppC {
}

implementation {
  components MainC, LedsC;

  components new ForwarderC(RecordMsg, ControlMsg);
  components new BaseStationC(RecordMsg, ControlMsg);

  components SerialActiveMessageC as UpControlC;
  components StartSplitControlC as StartUpControlC;
  components new SerialAMSenderC(AM_RECORDMSG) as UpAMSenderC;
  components new SerialAMReceiverC(AM_CONTROLMSG) as UpAMReceiverC;

  StartUpControlC -> MainC.Boot;
  StartUpControlC.Control -> UpControlC;

  ForwarderC.UpPacket -> UpAMSenderC;
  ForwarderC.UpAMSend -> UpAMSenderC;
  ForwarderC.UpReceive -> UpAMReceiverC;
  ForwarderC.UpPacketAcks -> UpAMSenderC;

#ifdef DOWNSTREAM
  components ActiveMessageC as DownControlC;
  components StartSplitControlC as StartDownControlC;
  components new AMSenderC(AM_CONTROLMSG) as DownAMSenderC;
  components new AMReceiverC(AM_RECORDMSG) as DownAMReceiverC;

  StartDownControlC -> MainC.Boot;
  StartDownControlC.Control -> DownControlC;

  ForwarderC.DownPacket -> DownAMSenderC;
  ForwarderC.DownAMSend -> DownAMSenderC;
  ForwarderC.DownReceive -> DownAMReceiverC;
  ForwarderC.DownPacketAcks -> DownAMSenderC;
#endif

  ForwarderC.Leds -> LedsC;

  BaseStationC.Forwarder -> ForwarderC;
}
