configuration SlaveAppC {
}

implementation {
  components MainC, LedsC;
  components TransportC, CalculateC;

  CalculateC.Leds -> LedsC;
  CalculateC.Transport -> TransportC;
}
