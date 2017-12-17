module StartSplitControlC {
  uses {
    interface Boot;
    interface SplitControl as Control;
  }
}
implementation {
  event void Boot.booted() {
    call Control.start();
  }
  event void Control.startDone(error_t err) {
    if (err != SUCCESS)
      call Control.start();
  }
  event void Control.stopDone(error_t err) {
    if (err != SUCCESS)
      call Control.stop();
  }
}
