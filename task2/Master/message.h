#ifndef MESSAGE_H
#define MESSAGE_H

#define N_NUMBERS 500

#define MSG_RESULT_MAX     0
#define MSG_RESULT_MIN     1
#define MSG_RESULT_SUM     2
#define MSG_RESULT_AVERAGE 3
#define MSG_RESULT_MEDIAN  4

#define MSG_RESULT_BITS   0x1f

#define AM_ID 6
#define SEND_DATA_INTERVAL 10

// 6
typedef nx_struct DataMsg {
  nx_uint16_t sequence_number;
  nx_uint32_t random_integer;
} DataMsg;

// 21
typedef nx_struct ResultMsg {
  nx_uint8_t group_id;
  nx_uint32_t max;
  nx_uint32_t min;
  nx_uint32_t sum;
  nx_uint32_t average;
  nx_uint32_t median;
} ResultMsg;


// 1
typedef nx_struct AckMsg {
  nx_uint8_t group_id;
} AckMsg;

// 2
typedef nx_struct QueryMsg {
  nx_uint16_t sequence_number;
} QueryMsg;

// 5
typedef nx_struct PartialResultMsg {
  nx_uint8_t type;
  nx_uint32_t result;
} PartialResultMsg;

#endif
