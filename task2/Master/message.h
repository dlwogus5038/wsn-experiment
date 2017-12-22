#ifndef MESSAGE_H
#define MESSAGE_H

#define N_NUMBERS 2000

#define MSG_RESULT_MAX     0
#define MSG_RESULT_MIN     1
#define MSG_RESULT_SUM     2
#define MSG_RESULT_AVERAGE 3
#define MSG_RESULT_MEDIAN  4

#define MSG_RESULT_BITS   0x1f

#define AM_ID 0
#define SEND_DATA_INTERVAL 10
#define TEST_SEND_INTERVAL 100

#define DATA_LOST_QUEUE_LEN 512
// Much smaller because overflow is not a big deal
#define DATA_ANSWER_QUEUE_LEN 16
#define RESULT_QUEUE_LEN 6

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
