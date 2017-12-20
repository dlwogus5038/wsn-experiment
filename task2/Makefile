all: install,0

compile,%: FORCE
	$(MAKE) -C $(shell python gen-target.py $*) telosb CFLAGS="$(shell python gen-cflags.py $*)"

install,%: FORCE
	$(MAKE) -C $(shell python gen-target.py $*) telosb install,$* CFLAGS="$(shell python gen-cflags.py $*)"

FORCE:
