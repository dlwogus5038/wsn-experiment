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
  #define MAX_COUNT (N_NUMBERS / 2 + 1)
  uint32_t numbers[N_NUMBERS];
  uint32_t partition(uint32_t *array, uint32_t begin, uint32_t end) {
    uint32_t beginOfLatterArray = begin, value = array[end], temp, i;
    for (i = begin; i < end; ++i) {
      if (array[i] < value) {
        temp = array[i];
        array[i] = array[beginOfLatterArray];
        array[beginOfLatterArray] = temp;
        ++beginOfLatterArray;
      }
    }
    temp = array[end];
    array[end] = array[beginOfLatterArray];
    array[beginOfLatterArray] = temp;
    return beginOfLatterArray;
  }
  uint32_t getMedian() {
    uint32_t begin = 0, end = count - 1, middle = (count-1) / 2;
    uint32_t place;
    uint32_t i, secondNumber;
    do {
      place = partition(numbers, begin, end);
      if(place > middle)
        end = place - 1;
      else if(place < middle)
        begin = place + 1;
      else
        break;
    } while(place != middle);
    if(count % 2)
      return numbers[middle];
    else {
      for(i = middle + 1, secondNumber = ~0u; i < count; ++i) {
        if(numbers[i] < secondNumber)
          secondNumber = numbers[i];
      }
      return (numbers[middle] + secondNumber) / 2;
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
    numbers[count] = number;
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
    median = getMedian();
    call Transport.sendResult(MSG_RESULT_MEDIAN, median);
    #endif
    #ifdef TASK_AVERAGE
    average = sum / count;
    call Transport.sendResult(MSG_RESULT_AVERAGE, average);
    #endif
  }
}
