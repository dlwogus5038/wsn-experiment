configuration SlaveAppC {
}

implementation {
  components MainC, LedsC;
  components TransportC, CalculateC;

  CalculateC.Transport -> TransportC;
}
