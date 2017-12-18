#include "message.h"

module NoSensorC {
  uses interface Forwarder<RecordMsg, ControlMsg>;
}
implementation {
  event void Forwarder.receive(ControlMsg *payload) {}
}
