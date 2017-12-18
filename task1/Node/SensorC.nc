#include "message.h"

module SensorC {
  uses {
    interface SplitControl as Control;
    interface Timer<TMilli> as Timer;
    interface Forwarder<RecordMsg, ControlMsg>;
  }
}
implementation {
  RecordMsg msg = {0, 0, 0, 0, 0};

  event void Forwarder.receive(ControlMsg *payload) {}

  event void Control.startDone(error_t err) {
    if (err == SUCCESS)
      call Timer.startPeriodic(INIT_SAMPLING_FREQUENCY);
  }

  event void Control.stopDone(error_t err) {}

  event void Timer.fired() {
    msg.nodeid = TOS_NODE_ID;
    ++msg.time;
    call Forwarder.send(&msg);
  }
}
