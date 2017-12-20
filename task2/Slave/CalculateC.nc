#include "message.h"

module CalculateC {
  uses {
    interface Leds;
    interface Transport;
  }
}

implementation {
  uint32_t count = 0;
  uint32_t numbers[N_NUMBERS];
  #ifdef DTASK_MIN
  uint32_t min = ~0; // INT_MAX
  #endif
  #ifdef DTASK_MAX
  uint32_t max = 0;
  #endif
  #if defined(DTASK_SUM) || defined(DTASK_AVERAGE)
  uint32_t sum = 0;
  #endif
  #ifdef DTASK_AVERAGE
  uint32_t average;
  #endif
  #ifdef DTASK_MEDIAN
  uint32_t median;
  void insertSort() {
    uint32_t i, temp;
    for(i = count - 1; i > 0; i--) {
      if(numbers[i] < numbers[i-1]) {
        temp = numbers[i];
        numbers[i] = numbers[i-1];
        numbers[i-1] = temp;
      }
      else
        break;
    }
  }
  void binaryInsertSort() {
    uint32_t low = 0, high = count - 2, mid, key = numbers[count - 1];
    if(count == 1)
      return;
    while(low < high) {
      mid = low + ((high - low + 1) >> 1);
      if(numbers[mid] < key)
        low = mid;
      else
        high = mid-1;
    }
    if(numbers[0] >= key) {
      memcpy(numbers + 1, numbers, (count - 1) * sizeof(uint32_t));
      numbers[0] = key;
      return;
    }
    else{
      memcpy(numbers + low + 2, numbers + low + 1, (count - 2 - low) * sizeof(uint32_t));
      numbers[low+1] = key;
    }
  }
  #endif

  event void Transport.receiveNumber(uint32_t number) {
    numbers[count++] = number;
    #ifdef DTASK_MIN
    min = number < min ? number:min;
    #endif
    #ifdef DTASK_MAX
    max = number > max ? number:max;
    #endif
    #if defined(DTASK_SUM) || defined(DTASK_AVERAGE)
    sum += number;
    #endif
    #ifdef DTASK_MEDIAN
    insertSort();
    #endif
  }

  event void Transport.receiveDone() {
    #ifdef DTASK_MIN
    call Transport.sendResult(MSG_RESULT_MIN, min);
    #endif
    #ifdef DTASK_MAX
    call Transport.sendResult(MSG_RESULT_MAX, max);
    #endif
    #ifdef DTASK_SUM
    call Transport.sendResult(MSG_RESULT_SUM, sum);
    #endif
    #ifdef DTASK_MEDIAN
    if(count % 2) {
      median = numbers[count / 2];
    }
    else {
      median = (numbers[count / 2] + numbers[(count /2) - 1]) / 2;
    }
    call Transport.sendResult(MSG_RESULT_MEDIAN, median);
    #endif
    #ifdef DTASK_AVERAGE
    average = sum / count;
    call Transport.sendResult(MSG_RESULT_AVERAGE, average);
    #endif
  }
}

