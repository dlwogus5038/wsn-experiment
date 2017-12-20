#include "message.h"

module CalculateC {
  uses {
    interface Transport;
  }
}

implementation {
  uint32_t count = 0;
  #ifdef TASK_MIN
  uint32_t min = ~0u; // INT_MAX
  #endif
  #ifdef TASK_MAX
  uint32_t max = 0;
  #endif
  #if defined(TASK_SUM) || defined(TASK_AVERAGE)
  uint32_t sum = 0;
  #endif
  #ifdef TASK_AVERAGE
  uint32_t average;
  #endif
  #ifdef TASK_MEDIAN
  uint32_t median;
  uint32_t numbers[N_NUMBERS];
  void insertSort(uint32_t key) {
    uint32_t i;
    for(i = count; i > 0; --i) {
      if(numbers[i-1] > key)
        numbers[i] = numbers[i-1];
      else
        break;
    }
    numbers[i] = key;
  }
  void binaryInsertSort(uint32_t key) {
    uint32_t low = 0, high = count - 1, mid;
    if(count == 0) {
      numbers[count] = key;
      return;
    }
    while(low < high) {
      mid = low + ((high - low + 1) / 2);
      if(numbers[mid] < key)
        low = mid;
      else
        high = mid-1;
    }
    if(numbers[0] >= key) {
      memmove(numbers + 1, numbers, count * sizeof(uint32_t));
      numbers[0] = key;
    }
    else{
      memmove(numbers + low + 2, numbers + low + 1, (count - 1 - low) * sizeof(uint32_t));
      numbers[low+1] = key;
    }
  }
  #endif

  event void Transport.receiveNumber(uint32_t number) {
    #ifdef TASK_MIN
    min = number < min ? number:min;
    #endif
    #ifdef TASK_MAX
    max = number > max ? number:max;
    #endif
    #if defined(TASK_SUM) || defined(TASK_AVERAGE)
    sum += number;
    #endif
    #ifdef TASK_MEDIAN
    insertSort(number);
    #endif
    ++count;
  }

  event void Transport.receiveDone() {
    #ifdef TASK_MIN
    call Transport.sendResult(MSG_RESULT_MIN, min);
    #endif
    #ifdef TASK_MAX
    call Transport.sendResult(MSG_RESULT_MAX, max);
    #endif
    #ifdef TASK_SUM
    call Transport.sendResult(MSG_RESULT_SUM, sum);
    #endif
    #ifdef TASK_MEDIAN
    if(count % 2) {
      median = numbers[count / 2];
    }
    else {
      median = (numbers[count / 2] + numbers[(count /2) - 1]) / 2;
    }
    call Transport.sendResult(MSG_RESULT_MEDIAN, median);
    #endif
    #ifdef TASK_AVERAGE
    average = sum / count;
    call Transport.sendResult(MSG_RESULT_AVERAGE, average);
    #endif
  }
}

