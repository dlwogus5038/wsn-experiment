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

  event void Transport.receiveNumber(uint32_t number) {
    numbers[count++] = number;
  }

  event void Transport.receiveDone() {

  }
}
