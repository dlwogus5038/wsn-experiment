#include <Timer.h>
#include <AM.h>
#include "forwarder.h"

generic module ForwarderC(typedef UpPayload, typedef DownPayload) {
  uses {
    interface Packet as UpPacket;
    interface AMSend as UpAMSend;
    interface Receive as UpReceive;
    interface PacketAcknowledgements as UpPacketAcks;

#ifdef DOWNSTREAM
    interface Packet as DownPacket;
    interface AMSend as DownAMSend;
    interface Receive as DownReceive;
    interface PacketAcknowledgements as DownPacketAcks;
#endif

    interface Leds;
  }
  provides interface Forwarder<UpPayload, DownPayload>;
}

implementation {
  // implicit busy if head != tail
  UpPayload upQueue[UP_QUEUE_LEN];
  uint32_t upHead = 0, upTail = 0;
  message_t upPacket;

#ifdef DOWNSTREAM
 // implicit busy if head != tail
  DownPayload downQueue[DOWN_QUEUE_LEN];
  uint32_t downHead = 0, downTail = 0;
  message_t downPacket;
  am_addr_t downNodes[] = {DOWNSTREAM};
#define DOWN_NODES_LEN (sizeof(downNodes) / sizeof(downNodes[0]))
  uint32_t downNodesPos = 0;
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

  task void upSendTask() {
    UpPayload *payload = (UpPayload *) call UpAMSend.getPayload(&upPacket, sizeof(UpPayload));
    if (!payload)
      goto error;
    memcpy(payload, upQueue + upHead, sizeof(UpPayload));
    if (
#ifndef BASESTATION
        call UpPacketAcks.requestAck(&upPacket) == SUCCESS &&
#endif
        call UpAMSend.send(UPSTREAM, &upPacket, sizeof(UpPayload)) == SUCCESS) {
      return;
    }
  error:
    post upSendTask();
  }

  event void UpAMSend.sendDone(message_t *msg, error_t err) {
    if (err == SUCCESS
#ifndef BASESTATION
        && call UpPacketAcks.wasAcked(msg)
#endif
       ) {
      upHead = (upHead + 1) % UP_QUEUE_LEN;
      reportSent();
      if (upHead != upTail)
        post upSendTask();
    } else
      post upSendTask();
  }

#ifdef DOWNSTREAM
  task void downSendTask() {
    if (downNodesPos == 0) {
      DownPayload *payload = (DownPayload *) call DownAMSend.getPayload(&downPacket, sizeof(DownPayload));
      if (!payload)
        goto error;
        memcpy(payload, downQueue + downHead, sizeof(DownPayload));
    }
    if (call DownPacketAcks.requestAck(&downPacket) == SUCCESS &&
        call DownAMSend.send(downNodes[downNodesPos], &downPacket, sizeof(DownPayload)) == SUCCESS)
      return;
  error:
    post downSendTask();
  }

  event void DownAMSend.sendDone(message_t *msg, error_t err) {
    if (err == SUCCESS && call DownPacketAcks.wasAcked(msg)) {
      if (++downNodesPos == DOWN_NODES_LEN) {
        downHead = (downHead + 1) % DOWN_QUEUE_LEN;
        downNodesPos = 0;
      }
      reportSent();
      if (downHead != downTail)
        post downSendTask();
    } else
      post downSendTask();
  }
#endif

  command void Forwarder.send(UpPayload *payload) {
    uint32_t newTail = (upTail + 1) % UP_QUEUE_LEN;
    if (newTail == upHead)
      reportError();
    else {
      memcpy(upQueue + upTail, payload, sizeof(UpPayload));
      if (upHead == upTail)
        post upSendTask();
      upTail = newTail;
    }
  }

#ifdef DOWNSTREAM
  event message_t *DownReceive.receive(message_t *msg, void *payload, uint8_t len) {
    if (len == sizeof(UpPayload)) {
      reportReceived();
      call Forwarder.send(payload);
    }
    return msg;
  }
#endif

  event message_t *UpReceive.receive(message_t *msg, void *payload, uint8_t len) {
    if (len == sizeof(DownPayload)) {
#ifdef DOWNSTREAM
      uint32_t newTail = (downTail + 1) % DOWN_QUEUE_LEN;
      if (newTail == downHead)
        reportError();
      else {
        memcpy(downQueue + downTail, payload, sizeof(DownPayload));
        if (downHead == downTail)
          post downSendTask();
        downTail = newTail;
      }
#endif
      reportReceived();
      signal Forwarder.receive(payload);
    }
    return msg;
  }
}
