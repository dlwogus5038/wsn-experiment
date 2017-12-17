// $Id: BlinkToRadio.h,v 1.4 2006/12/12 18:22:52 vlahan Exp $

#ifndef MESSAGE_H
#define MESSAGE_H

enum {
  AM_CONTROLMSG = 6,
  AM_RECORDMSG = 7
};

#define INIT_SAMPLING_FREQUENCY  100
#define ROOT

typedef nx_struct RecordMsg {
  nx_uint8_t nodeid;
  nx_uint16_t time;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
  nx_uint16_t light;
} RecordMsg;

typedef nx_struct ControlMsg {
  nx_uint8_t frequency;
} ControlMsg;

#endif
