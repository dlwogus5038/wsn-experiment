#include <AM.h>
#include "message.h"

module MasterC {
  uses {
    interface Boot;
    interface Leds;

    interface SplitControl as RadioControl;

    interface Packet as RadioPacket;
    interface AMSend as RadioAMSend;
#ifdef TASK_RECEIVE
    interface SplitControl as SerialControl;

    interface Packet as SerialPacket;
    interface AMSend as SerialAMSend;

    interface Receive as RadioReceive;
#endif

#ifdef TASK_SEND
    interface Timer<TMilli> as Timer;
#endif
  }
}

implementation {
  uint8_t boot_state = 0;

#ifdef TASK_SEND
  uint32_t numbers[N_NUMBERS];
  uint32_t pos = 0;
  uint8_t sending = FALSE;
  message_t data_packet;
#endif

#ifdef TASK_RECEIVE
#define MASTER_ACK_QUEUE_LEN 32
#define MASTER_RESULT_QUEUE_LEN 32
  AckMsg ack_queue[MASTER_ACK_QUEUE_LEN];
  uint32_t ack_queue_head = 0, ack_queue_tail = 0;
  message_t ack_packet;
  ResultMsg result_queue[MASTER_RESULT_QUEUE_LEN];
  uint32_t result_queue_head = 0, result_queue_tail = 0;
  message_t result_packet;
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
#ifdef TASK_SEND
    // Init numbers
    // Best situation for insertion sort
    uint32_t i;
    for (i = 0; i < N_NUMBERS; ++i)
      numbers[N_NUMBERS - i - 1] = i;
#endif
#ifdef TASK_RECEIVE
    call SerialControl.start();
#endif
    call RadioControl.start();
  }

  void testStart() {
#ifdef TASK_SEND
#ifdef TASK_RECEIVE
    if (boot_state == 2)
#else
    if (boot_state == 1)
#endif
      call Timer.startPeriodic(SEND_DATA_INTERVAL);
#endif
  }


#ifdef TASK_RECEIVE
  event void SerialControl.startDone(error_t err) {
    if (err == SUCCESS) {
      ++boot_state;
      testStart();
    } else
      call SerialControl.start();
  }

  event void SerialControl.stopDone(error_t err) {}
#endif

  event void RadioControl.startDone(error_t err) {
    if (err == SUCCESS) {
      ++boot_state;
      testStart();
    } else
      call RadioControl.start();
  }

  event void RadioControl.stopDone(error_t err) {}

#ifdef TASK_SEND
  event void Timer.fired() {
    if (sending)
      goto error;
    if (pos != N_NUMBERS) {
      DataMsg *payload = (DataMsg *) call RadioAMSend.getPayload(&data_packet, sizeof(DataMsg));
      if (!payload)
        goto error;
      payload->sequence_number = pos + 1;
      payload->random_integer = numbers[pos];
      if (call RadioAMSend.send(AM_BROADCAST_ADDR, &data_packet, sizeof(DataMsg)) != SUCCESS)
        goto error;
      sending = TRUE;
    }
    return;
  error:
    reportError();
  }
#endif

#ifdef TASK_RECEIVE
  task void sendAck() {
    AckMsg *payload = (AckMsg *) call RadioAMSend.getPayload(&ack_packet, sizeof(AckMsg));
    if (!payload)
      goto error;
    memcpy(payload, ack_queue + ack_queue_head, sizeof(AckMsg));
    if (call RadioAMSend.send(3 * (payload->group_id - 1) + 1, &ack_packet, sizeof(AckMsg)) == SUCCESS)
      return;
  error:
    post sendAck();
  }
#endif

  event void RadioAMSend.sendDone(message_t *msg, error_t err) {
#ifdef TASK_SEND
    if (pos != N_NUMBERS) {
      sending = FALSE;
      if (err == SUCCESS) {
        ++pos;
        if (pos == N_NUMBERS)
          call Timer.stop();
        reportSent();
      } else
        reportError();
      return;
    }
#endif
#ifdef TASK_RECEIVE
  if (err == SUCCESS) {
    ack_queue_head = (ack_queue_head + 1) % MASTER_ACK_QUEUE_LEN;
    reportSent();
    if (ack_queue_head != ack_queue_tail)
      post sendAck();
  } else
    post sendAck();
#endif
  }

#ifdef TASK_RECEIVE
  task void sendResult() {
    ResultMsg *payload = (ResultMsg *) call SerialAMSend.getPayload(&result_packet, sizeof(ResultMsg));
    if (!payload)
      goto error;
    memcpy(payload, result_queue + result_queue_head, sizeof(ResultMsg));
    if (call SerialAMSend.send(0, &result_packet, sizeof(ResultMsg)) == SUCCESS)
      return;
  error:
    post sendResult();
  }

  event void SerialAMSend.sendDone(message_t *msg, error_t err) {
    if (err == SUCCESS) {
      result_queue_head = (result_queue_head + 1) % MASTER_RESULT_QUEUE_LEN;
      if (result_queue_head != result_queue_tail)
        post sendResult();
    } else
      post sendResult();
  }
#endif

#ifdef TASK_RECEIVE
  event message_t *RadioReceive.receive(message_t *msg, void *payload, uint8_t len) {
#ifdef TASK_SEND
    // Ignore all message before send done
    if (pos != N_NUMBERS)
      return msg;
#endif
    if (len == sizeof(ResultMsg)) {
      uint32_t new_ack_tail = (ack_queue_head + 1) % MASTER_ACK_QUEUE_LEN;
      uint32_t new_result_tail = (result_queue_head + 1) % MASTER_RESULT_QUEUE_LEN;
      if (new_ack_tail == ack_queue_tail || new_result_tail == result_queue_tail)
        reportError();
      else {
        ResultMsg *result = (ResultMsg *) payload;
        ack_queue[ack_queue_tail].group_id = result->group_id;
        memcpy(result_queue + result_queue_tail, result, sizeof(ResultMsg));
        if (ack_queue_head == ack_queue_tail)
          post sendAck();
        if (result_queue_head == result_queue_tail)
          post sendResult();
        ack_queue_tail = new_ack_tail;
        result_queue_tail = new_result_tail;
        reportReceived();
      }
    }
    return msg;
  }
#endif
}
