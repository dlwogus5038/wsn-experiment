#include "message.h"

module TransportC {
  uses {
    interface Boot;
    interface Leds;

    interface SplitControl as Control;

    interface Packet;
    interface AMSend;
    interface Receive;
    interface AMPacket;
    interface PacketAcknowledgements as PacketAcks;
  }
  provides interface Transport;
}

implementation {
  uint8_t data_received = FALSE;

  uint8_t query_num = 0;

  message_t result_packet;

#ifdef TASK_COLLECT
  ResultMsg result_data = {
    GROUP_ID
  };
  uint32_t result_mask = 0;
  uint8_t result_sent = FALSE;
#endif

  void reportError() {
    call Leds.led0Toggle();
  }
  void reportSent() {
    call Leds.led1Toggle();
  }
  void reportReceived() {
    call Leds.led2Toggle();
  }

  event void Boot.booted() {
    call Control.start();
  }

  event void Control.startDone(error_t err) {
    if (err != SUCCESS)
      call Control.start();
  }

  event void Control.stopDone(error_t err) {}

#ifdef TASK_COLLECT
  // Send result to master receiver
  task void sendResult() {
    ResultMsg *payload = (ResultMsg *) call AMSend.getPayload(&result_packet, sizeof(ResultMsg));
    if (!payload)
      goto error;
    memcpy(payload, &result_data, sizeof(ResultMsg));
    if (call AMSend.send(MASTER_RECEIVE_ID, &result_packet, sizeof(ResultMsg)) == SUCCESS)
      return;
  error:
    post sendResult();
  }
#else
  task void sendResult() {
  }
#endif

  event void AMSend.sendDone(message_t *msg, error_t err) {
#ifdef TASK_COLLECT
    if (err != SUCCESS)
      post sendResult();
    else
      reportSent();
#endif
  }

  command void Transport.sendResult(uint8_t type, uint32_t result) {
#ifdef TASK_COLLECT
    if (result_sent)
      return;
    result_mask |= 1 << type;
    switch (type) {
      case MSG_RESULT_MAX:
        result_data.max = result;
        break;
      case MSG_RESULT_MIN:
        result_data.min = result;
        break;
      case MSG_RESULT_SUM:
        result_data.sum = result;
        break;
      case MSG_RESULT_AVERAGE:
        result_data.average = result;
        break;
      case MSG_RESULT_MEDIAN:
        result_data.median = result;
        break;
    }
    if (result_mask == MSG_RESULT_BITS) {
      result_sent = TRUE;
      post sendResult();
    }
#else
#endif
  }

  event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
    if (len == sizeof(DataMsg)) {
      DataMsg *data = (DataMsg *) payload;
      signal Transport.receiveNumber(data->random_integer);
      if (data->sequence_number == N_NUMBERS)
        signal Transport.receiveDone();
      reportReceived();
    }
    return msg;
  }
}
