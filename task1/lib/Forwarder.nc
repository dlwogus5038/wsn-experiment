interface Forwarder<UpPayload, DownPayload> {
  command void send(UpPayload *payload);
  event void receive(DownPayload *payload);
}
