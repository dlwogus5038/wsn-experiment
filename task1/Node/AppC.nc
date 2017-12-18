#include <Timer.h>
#include "message.h"

configuration AppC {
}

implementation {
  components MainC, LedsC;

  components ActiveMessageC as RadioControlC;
  components StartSplitControlC as StartRadioControlC;
  StartRadioControlC -> MainC.Boot;
  StartRadioControlC.Control -> RadioControlC;

#ifdef BASESTATION
  components SerialActiveMessageC as SerialControlC;
  components StartSplitControlC as StartSerialControlC;
  StartSerialControlC -> MainC.Boot;
  StartSerialControlC.Control -> SerialControlC;
  components new SerialAMSenderC(AM_RECORDMSG) as UpAMSenderC;
  components new SerialAMReceiverC(AM_CONTROLMSG) as UpAMReceiverC;
#else
  components new AMSenderC(AM_RECORDMSG) as UpAMSenderC;
  components new AMReceiverC(AM_CONTROLMSG) as UpAMReceiverC;
#endif

  components new ForwarderC(RecordMsg, ControlMsg);

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

#ifdef SENSOR
  components SensorC, new TimerMilliC() as Timer;
  components new HamamatsuS1087ParC();
  components new SensirionSht11C();

  SensorC.Control -> RadioControlC;
  SensorC.Timer -> Timer;
  SensorC.Forwarder -> ForwarderC;
  SensorC.Temperature -> SensirionSht11C.Temperature;
  SensorC.Humidity -> SensirionSht11C.Humidity;
  SensorC.Light -> HamamatsuS1087ParC;
#else
  components NoSensorC;
  NoSensorC.Forwarder -> ForwarderC;
#endif
}
