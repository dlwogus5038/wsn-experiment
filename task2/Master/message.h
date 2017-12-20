#ifndef MESSAGE_H
#define MESSAGE_H

#define N_NUMBERS 2000

#define MSG_RESULT_MAX     0
#define MSG_RESULT_MIN     1
#define MSG_RESULT_SUM     2
#define MSG_RESULT_AVERAGE 3
#define MSG_RESULT_MEDIAN  4

#define AM_ID 6
#define SEND_DATA_INTERVAL 10

typedef nx_struct DataMsg {
  nx_uint16_t sequence_number;
  nx_uint32_t random_integer;
} DataMsg;

typedef nx_struct ResultMsg {
  nx_uint8_t group_id;
  nx_uint32_t max;
  nx_uint32_t min;
  nx_uint32_t sum;
  nx_uint32_t average;
  nx_uint32_t median;
} ResultMsg;

typedef nx_struct AckMsg {
  nx_uint32_t group_id;
} AckMsg;

#endif
