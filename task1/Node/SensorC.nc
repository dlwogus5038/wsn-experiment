#include "message.h"

module SensorC {
  uses {
    interface SplitControl as Control;
    interface Timer<TMilli> as Timer;
    interface Forwarder<RecordMsg, ControlMsg>;

    interface Counter<TMilli,uint32_t> as LocalTime;
    interface Read<uint16_t> as Temperature;
    interface Read<uint16_t> as Humidity;
    interface Read<uint16_t> as Light;

    interface Leds;
  }
}
implementation {
  RecordMsg msg;
  uint32_t count = 0;
#ifdef RECORD_QUEUE
  typedef struct RecordData {
    uint32_t time;
    uint16_t temperature;
    uint16_t humidity;
    uint16_t light;
  } RecordData;
#ifndef RECORD_QUEUE_LEN
#define RECORD_QUEUE_LEN 128
#endif
  RecordData recordQueue[RECORD_QUEUE_LEN];
  uint32_t recordHead = 0, recordTail = 0;
  uint32_t recordTemperatureTail = 0;
  uint32_t recordHumidityTail = 0;
  uint32_t recordLightTail = 0;
#else
  uint8_t state = 0;
#endif

  void reportError() {
    call Leds.led0Toggle();
  }

  event void Forwarder.receive(ControlMsg *payload) {
    call Timer.startPeriodic(payload->frequency);
  }

  event void Control.startDone(error_t err) {
    if (err == SUCCESS) {
      msg.nodeid = TOS_NODE_ID;
      call Timer.startPeriodic(INIT_SAMPLING_FREQUENCY);
    }
  }

  event void Control.stopDone(error_t err) {}

  event void Timer.fired() {
#ifdef RECORD_QUEUE
    uint32_t newTail = (recordTail + 1) % RECORD_QUEUE_LEN;
    if (newTail != recordHead) {
      recordQueue[recordTail].time = call LocalTime.get();
      recordTail = newTail;
#else
    if (state == 0) {
      msg.time = call LocalTime.get();
#endif
      while (call Temperature.read() != SUCCESS);
      while (call Humidity.read() != SUCCESS);
      while (call Light.read() != SUCCESS);
    }
#ifdef SENSOR_REPORT_ERROR
    else
      reportError();
#endif
  }

  void checkSend() {
#ifdef RECORD_QUEUE
    if (recordHead != recordTemperatureTail &&
        recordHead != recordHumidityTail &&
        recordHead != recordLightTail) {
      recordHead = (recordHead + 1) % RECORD_QUEUE_LEN;
      msg.time = recordQueue[recordHead].time;
      msg.temperature = recordQueue[recordHead].temperature;
      msg.humidity = recordQueue[recordHead].humidity;
      msg.light = recordQueue[recordHead].light;
#else
    if (state == 3) {
      state = 0;
#endif
      msg.count = count;
      call Forwarder.send(&msg);
      ++count;
    }
  }

  event void Temperature.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
#ifdef RECORD_QUEUE
      recordQueue[recordTemperatureTail].temperature = data;
      recordTemperatureTail = (recordTemperatureTail + 1) % RECORD_QUEUE_LEN;
#else
      msg.temperature = data;
      ++state;
#endif
      checkSend();
    } else
      call Temperature.read();
  }

  event void Humidity.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
#ifdef RECORD_QUEUE
      recordQueue[recordHumidityTail].humidity = data;
      recordHumidityTail = (recordHumidityTail + 1) % RECORD_QUEUE_LEN;
#else
      msg.humidity = data;
      ++state;
#endif
      checkSend();
    } else
      call Humidity.read();
  }

  event void Light.readDone(error_t result, uint16_t data) {
    if (result == SUCCESS) {
#ifdef RECORD_QUEUE
      recordQueue[recordLightTail].light = data;
      recordLightTail = (recordLightTail + 1) % RECORD_QUEUE_LEN;
#else
      msg.light = data;
      ++state;
#endif
      checkSend();
    } else
      call Light.read();
  }

  async event void LocalTime.overflow() {}
}
