#include "message.h"

module SensorC {
  uses {
    interface SplitControl as Control;
    interface Timer<TMilli> as Timer;
    interface Forwarder<RecordMsg, ControlMsg>;

    interface Read<uint16_t> as Temperature;
    interface Read<uint16_t> as Humidity;
    interface Read<uint16_t> as Light;
  }
}
implementation {
  RecordMsg msg;
  uint8_t state = 0;

  event void Forwarder.receive(ControlMsg *payload) {}

  event void Control.startDone(error_t err) {
    if (err == SUCCESS) {
      msg.nodeid = TOS_NODE_ID;
      msg.time = 0;
      call Timer.startPeriodic(INIT_SAMPLING_FREQUENCY);
    }
  }

  event void Control.stopDone(error_t err) {}

  event void Timer.fired() {
    if (state == 0) {
      call Temperature.read();
      call Humidity.read();
      call Light.read();
    }
  }

  void checkSend() {
    if (state == 3) {
      call Forwarder.send(&msg);
      ++msg.time;
      state = 0;
    }
  }

  event void Temperature.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
      msg.temperature = data;
      ++state;
      checkSend();
    } else
      call Temperature.read();
  }

  event void Humidity.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
      msg.humidity = data;
      ++state;
      checkSend();
    } else
      call Humidity.read();
  }

  event void Light.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
      msg.light = data;
      ++state;
      checkSend();
    } else
      call Light.read();
  }
}
