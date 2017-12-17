generic module BaseStationC(typedef UpPayload, typedef DownPayload) {
  uses interface Forwarder<UpPayload, DownPayload>;
}
implementation {
  event void Forwarder.receive(DownPayload *payload) {}
}
