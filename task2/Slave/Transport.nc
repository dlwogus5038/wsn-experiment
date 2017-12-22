interface Transport {
  event void receiveNumber(uint32_t number);
  event void receiveDone();
  command void sendResult(uint8_t type, uint32_t result);
  command void sendDone();
}
