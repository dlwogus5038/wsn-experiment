#include "message.h"

module TransportC {
  uses {
    interface Boot;
    interface Leds;

    interface Timer<TMilli> as Timer;

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
  // data_seq == N_NUMBERS && data_lost_head == data_lost_tail
  // and data_answer_head == data_answer_tail implies data_received
  uint16_t data_seq = 0;
  uint16_t data_lost[DATA_LOST_QUEUE_LEN];
  uint32_t data_lost_head = 0, data_lost_tail = 0;

#if defined(TASK_MAX) || defined(TASK_MIN) || defined(TASK_SUM) || defined(TASK_AVERAGE) || defined(TASK_MEDIAN)
#define TASK_CALCULATE
#endif

#ifdef TASK_BACKUP
  uint32_t data[N_NUMBERS];
  typedef struct AnswerData {
    am_addr_t nodeid;
    uint16_t sequence_number;
  } AnswerData;
  AnswerData data_answer[DATA_ANSWER_QUEUE_LEN];
  uint32_t data_answer_head = 0, data_answer_tail = 0;
#endif

#ifdef PEERS_ID
  am_addr_t peers_id[] = {PEERS_ID};
#define PEERS_ID_LEN (sizeof(peers_id) / sizeof(peers_id[0]))
#endif

#ifdef BACKUPS_ID
  am_addr_t backups_id[] = {BACKUPS_ID};
#define BACKUPS_ID_LEN (sizeof(backups_id) / sizeof(backups_id[0]))
  uint32_t backups_pos = 0;
#endif

#ifdef TASK_COLLECT
  ResultMsg result_data = {GROUP_ID};
  uint32_t result_mask = 0;
  uint8_t result_send_enabled = TRUE;
#else
  PartialResultMsg result_queue[RESULT_QUEUE_LEN];
  uint32_t result_queue_head = 0, result_queue_tail = 0;
#endif

  // Send priority result (with ack if partial result), answer, query
  message_t packet, ack_packet;
  enum {NOT_SENDING, SENDING_RESULT, SENDING_ANSWER, SENDING_QUERY};
  uint8_t sending = NOT_SENDING;

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
    else
      call Timer.startPeriodic(TEST_SEND_INTERVAL);
  }

  event void Control.stopDone(error_t err) {}

  task void send() {
#ifdef TASK_COLLECT
    if (result_mask == MSG_RESULT_BITS && result_send_enabled) {
      ResultMsg *payload = (ResultMsg *) call AMSend.getPayload(&packet, sizeof(ResultMsg));
      sending = SENDING_RESULT;
      if (!payload)
        goto error;
      memcpy(payload, &result_data, sizeof(ResultMsg));
      if (call AMSend.send(MASTER_RECEIVE_ID, &packet, sizeof(ResultMsg)) != SUCCESS)
        goto error;
      return;
    }
#else
    if (result_queue_head != result_queue_tail) {
      PartialResultMsg *payload = (PartialResultMsg *) call AMSend.getPayload(&ack_packet, sizeof(PartialResultMsg));
      sending = SENDING_RESULT;
      if (!payload)
        goto error;
      memcpy(payload, result_queue + result_queue_head, sizeof(PartialResultMsg));
      if (call PacketAcks.requestAck(&ack_packet) == SUCCESS &&
          call AMSend.send(SLAVE_COLLECT_ID, &ack_packet, sizeof(PartialResultMsg)) != SUCCESS)
        goto error;
      return;
    }
#endif
#ifdef TASK_BACKUP
    if (data_answer_head != data_answer_tail) {
      AnswerData *answer = data_answer + data_answer_head;
      DataMsg *payload = (DataMsg *) call AMSend.getPayload(&packet, sizeof(DataMsg));
      sending = SENDING_ANSWER;
      if (!payload)
        goto error;
      payload->sequence_number = answer->sequence_number;
      payload->random_integer = data[answer->sequence_number - 1];
      if (call AMSend.send(answer->nodeid, &packet, sizeof(DataMsg)) != SUCCESS)
        goto error;
      return;
    }
#endif
#if defined(BACKUPS_ID) && defined(TASK_CALCULATE)
    if (data_lost_head != data_lost_tail && backups_pos < BACKUPS_ID_LEN
#ifdef QUERY_AFTER_SENDING
        && data_seq == N_NUMBERS
#endif
      ) {
      QueryMsg *payload = (QueryMsg *) call AMSend.getPayload(&packet, sizeof(QueryMsg));
      sending = SENDING_QUERY;
      if (!payload)
        goto error;
      payload->sequence_number = data_lost[data_lost_head];
      if (call AMSend.send(backups_id[backups_pos], &packet, sizeof(QueryMsg)) != SUCCESS)
        goto error;
      return;
    }
#endif
    sending = NOT_SENDING;
    return;
  error:
    post send();
  }

  event void Timer.fired() {
    if (sending == NOT_SENDING) {
#ifdef TASK_COLLECT
      result_send_enabled = TRUE;
#endif
#ifdef BACKUPS_ID
      backups_pos = 0;
#endif
      post send();
    }
  }

  event void AMSend.sendDone(message_t *msg, error_t result) {
    if (result == SUCCESS
#ifndef TASK_COLLECT
        && (sending != SENDING_RESULT || call PacketAcks.wasAcked(msg))
#endif
       ) {
      reportSent();
      switch (sending) {
        case SENDING_RESULT:
#ifdef TASK_COLLECT
          result_send_enabled = FALSE;
#else
          result_queue_head = (result_queue_head + 1) / RESULT_QUEUE_LEN;
#endif
          break;
#ifdef BACKUPS_ID
        case SENDING_QUERY:
          ++backups_pos;
          break;
#endif
#ifdef TASK_BACKUP
        case SENDING_ANSWER:
          data_answer_head = (data_answer_head + 1) % DATA_ANSWER_QUEUE_LEN;
          break;
#endif
      }
    }
    post send();
  }

  command void Transport.sendResult(uint8_t type, uint32_t result) {
#ifdef TASK_COLLECT
    if (result_mask & (1 << type))
      return;
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
      default:
        return;
    }
    result_mask |= 1 << type;
    if (result_mask == MSG_RESULT_BITS && sending == NOT_SENDING)
      post send();
#else
    uint32_t new_result_tail = (result_queue_tail + 1) % RESULT_QUEUE_LEN;
    if (new_result_tail == result_queue_head)
      reportError();
    else {
      result_queue[result_queue_tail].type = type;
      result_queue[result_queue_tail].result = result;
      result_queue_tail = new_result_tail;
      if (sending == NOT_SENDING)
        post send();
    }
#endif
  }

  event message_t *Receive.receive(message_t *msg, void *payload, uint8_t len) {
    am_addr_t source = call AMPacket.source(msg);
    if (len == sizeof(DataMsg)) {
      DataMsg *data_msg = (DataMsg *) payload;
      if ((data_seq == N_NUMBERS && data_lost_head == data_lost_tail) ||
          data_msg->sequence_number == 0 || data_msg->sequence_number > N_NUMBERS)
        return msg;
      if (source != MASTER_SEND_ID) {
#ifdef BACKUPS_ID
        uint32_t i;
        for (i = 0; i < BACKUPS_ID_LEN; ++i)
          if (backups_id[i] == source)
            break;
        if (i == BACKUPS_ID_LEN)
          return msg;
#else
        return msg;
#endif
      }
      if (data_msg->sequence_number <= data_seq) {
        if (data_lost_head != data_lost_tail &&
            data_msg->sequence_number == data_lost[data_lost_head]) {
          data_lost_head = (data_lost_head + 1) % DATA_LOST_QUEUE_LEN;
#ifdef BACKUPS_ID
          backups_pos = 0;
#endif
        } else
          return msg;
      } else {
        uint32_t new_lost_tail = DATA_LOST_QUEUE_LEN;
        while (TRUE) {
          ++data_seq;
          if (data_msg->sequence_number == data_seq)
            break;
          new_lost_tail = (data_lost_tail + 1) % DATA_LOST_QUEUE_LEN;
          if (new_lost_tail == data_lost_head) {
            reportError();
            data_seq = data_msg->sequence_number - 1;
          } else {
            data_lost[data_lost_tail] = data_seq;
            data_lost_tail = new_lost_tail;
          }
        }
#ifndef QUERY_AFTER_SENDING
        if (new_lost_tail != DATA_LOST_QUEUE_LEN && sending == NOT_SENDING)
          post send();
#endif
      }
#ifdef TASK_BACKUP
      data[data_msg->sequence_number - 1] = data_msg->random_integer;
#endif
      reportReceived();
      signal Transport.receiveNumber(data_msg->random_integer);
      if (data_seq == N_NUMBERS) {
        if (data_lost_head == data_lost_tail)
          signal Transport.receiveDone();
#ifdef QUERY_AFTER_SENDING
        else if (sending == NOT_SENDING)
          post send();
#endif
      }
    }
#if defined(TASK_BACKUP) && defined(PEERS_ID)
    else if (len == sizeof(QueryMsg)) {
      QueryMsg *query = (QueryMsg *) payload;
      uint32_t i;
      if (query->sequence_number == 0 || query->sequence_number > data_seq)
        return msg;
      for (i = 0; i < PEERS_ID_LEN; ++i)
        if (peers_id[i] == source)
          break;
      if (i == PEERS_ID_LEN)
        return msg;
      for (i = data_lost_head; i != data_lost_tail; i = (i + 1) % DATA_LOST_QUEUE_LEN)
        if (data_lost[i] == query->sequence_number)
          return msg;
      reportReceived();
      i = (data_answer_tail + 1) % DATA_ANSWER_QUEUE_LEN;
      if (data_answer_head != i) {
        data_answer[data_answer_tail].nodeid = source;
        data_answer[data_answer_tail].sequence_number = query->sequence_number;
        data_answer_tail = i;
        if (sending == NOT_SENDING)
          post send();
      } else
        reportError();
    }
#endif
#if defined(TASK_COLLECT) && defined(PEERS_ID)
    else if (len == sizeof(PartialResultMsg)) {
      PartialResultMsg *result = (PartialResultMsg *) payload;
      uint32_t i;
      for (i = 0; i < PEERS_ID_LEN; ++i)
        if (peers_id[i] == source)
          break;
      if (i == PEERS_ID_LEN)
        return msg;
      reportReceived();
      call Transport.sendResult(result->type, result->result);
    }
#endif
#ifdef TASK_COLLECT
    else if (len == sizeof(AckMsg)) {
      AckMsg *ack = (AckMsg *) payload;
      if (source == MASTER_RECEIVE_ID && ack->group_id == GROUP_ID) {
        result_send_enabled = FALSE;
        call Timer.stop();
      }
    }
#endif
    return msg;
  }
}
