#include "message.h"

module CalculateC {
  uses {
    interface Transport;
    interface Leds;

#if defined(TASK_MEDIAN) && !defined(MEDIAN_AFTER_SENDING)
    interface Msp430DmaChannel;
#endif
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

  void reportError() {
    call Leds.led0Toggle();
  }

#ifdef TASK_MEDIAN
  #ifdef MEDIAN_AFTER_SENDING
    uint32_t numbers[N_NUMBERS];
    uint32_t partition(uint32_t *array, uint32_t begin, uint32_t end) {
      uint32_t beginOfLatterArray = begin, value, temp, i;
      uint32_t mid = (begin + end) / 2;
      if((array[begin] <= array[mid] && array[mid] < array[end]) ||
        (array[end] < array[mid] && array[mid] <= array[begin])) {
        value = array[mid];
        array[mid] = array[end];
      }
      else if((array[mid] <= array[begin] && array[begin] < array[end]) ||
              (array[end] < array[begin] && array[begin] <= array[mid])) {
        value = array[begin];
        array[begin] = array[end];
      } else
        value = array[end];
      for (i = begin; i < end; ++i) {
        if (array[i] < value) {
          temp = array[i];
          array[i] = array[beginOfLatterArray];
          array[beginOfLatterArray] = temp;
          ++beginOfLatterArray;
        }
      }
      array[end] = array[beginOfLatterArray];
      array[beginOfLatterArray] = value;
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
  #else
    #define MAX_COUNT (N_NUMBERS / 2 + 1)
    uint32_t numbers[MAX_COUNT + 1], numbers_num = 0;
    uint32_t insert_queue[INSERT_QUEUE_LEN];
    uint32_t insert_head = 0, insert_tail = 0;
    uint8_t done = FALSE;
    uint32_t insert_pos = 0;

    void sendMedian() {
      if(count % 2)
        call Transport.sendResult(MSG_RESULT_MEDIAN, numbers[count / 2]);
      else
        call Transport.sendResult(MSG_RESULT_MEDIAN,
          (numbers[count / 2] + numbers[(count /2) - 1]) / 2);
    }

    task void insertNumber() {
      uint32_t key = insert_queue[insert_head];
      uint32_t low = 0, high = numbers_num, mid;
      while (low < high) {
        mid = low + (high - low) / 2;
        if(numbers[mid] > key)
          high = mid;
        else
          low = mid + 1;
      }
      if (numbers_num - low < DMA_MEMMOVE_THRESHOLD || low == numbers_num) {
        if (low != numbers_num)
          memmove(numbers + low + 1, numbers + low, sizeof(uint32_t) * (numbers_num - low));
        numbers[low] = key;
        if (numbers_num < MAX_COUNT)
          ++numbers_num;
        insert_head = (insert_head + 1) % INSERT_QUEUE_LEN;
        if (insert_head != insert_tail)
          post insertNumber();
        else if (done) {
          sendMedian();
          call Transport.sendDone();
        }
      } else {
        insert_pos = low;
        if (call Msp430DmaChannel.setupTransfer(
            DMA_BURST_BLOCK_TRANSFER,
            DMA_TRIGGER_DMAREQ,
            DMA_EDGE_SENSITIVE,
            numbers + low + 1,
            numbers + low,
            sizeof(uint32_t) * (numbers_num - low),
            DMA_BYTE,
            DMA_BYTE,
            DMA_ADDRESS_INCREMENTED,
            DMA_ADDRESS_INCREMENTED
           ) != SUCCESS)
          call Leds.led0Toggle();
        else if (call Msp430DmaChannel.startTransfer() != SUCCESS)
          call Leds.led0Toggle();
        else if (call Msp430DmaChannel.softwareTrigger() != SUCCESS)
          call Leds.led0Toggle();
      }
    }
    async event void Msp430DmaChannel.transferDone(error_t result) {
      if (result == SUCCESS) {
        numbers[insert_pos] = insert_queue[insert_head];
        if (numbers_num < MAX_COUNT)
          ++numbers_num;
        insert_head = (insert_head + 1) % INSERT_QUEUE_LEN;
        if (insert_head != insert_tail)
          post insertNumber();
        else if (done) {
          sendMedian();
          call Transport.sendDone();
        }
      } else
        reportError();
    }
  #endif
#endif

  event void Transport.receiveNumber(uint32_t number) {
    #ifdef TASK_MEDIAN
      #ifdef MEDIAN_AFTER_SENDING
        numbers[count] = number;
      #else
        uint32_t new_tail = (insert_tail + 1) % INSERT_QUEUE_LEN;
        if (new_tail == insert_head)
          reportError();
        else {
          insert_queue[insert_tail] = number;
          if (insert_head == insert_tail)
            post insertNumber();
          insert_tail = new_tail;
        }
      #endif
    #endif
    #ifdef TASK_MIN
    min = number < min ? number:min;
    #endif
    #ifdef TASK_MAX
    max = number > max ? number:max;
    #endif
    #if defined(TASK_SUM) || defined(TASK_AVERAGE)
    sum += number;
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
    #ifdef TASK_AVERAGE
    call Transport.sendResult(MSG_RESULT_AVERAGE, sum / count);
    #endif
    #ifdef TASK_MEDIAN
      #ifdef MEDIAN_AFTER_SENDING
        call Transport.sendResult(MSG_RESULT_MEDIAN, getMedian());
        call Transport.sendDone();
      #else
        done = TRUE;
        if (insert_head == insert_tail) {
          sendMedian();
          call Transport.sendDone();
        }
      #endif
    #else
      call Transport.sendDone();
    #endif
  }
}
