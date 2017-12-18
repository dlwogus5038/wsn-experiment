all: node0

compile,%: FORCE
	$(MAKE) -C Node telosb CFLAGS="$(shell python gen-cflags.py $*)"

install,%: FORCE
	$(MAKE) -C Node telosb install,$* CFLAGS="$(shell python gen-cflags.py $*)"

FORCE:
