CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -fno-omit-frame-pointer
BUILD_DIR ?= build

HOOK_SO := $(BUILD_DIR)/libcap_swap_hook.so
MANUAL_POC := $(BUILD_DIR)/manual_toctou_poc
SWAP_LOOP := $(BUILD_DIR)/swap_loop

.PHONY: all clean

all: $(HOOK_SO) $(MANUAL_POC) $(SWAP_LOOP)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(HOOK_SO): src/libcap_swap_hook.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -shared -fPIC -o $@ $< -ldl

$(MANUAL_POC): src/manual_toctou_poc.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $<

$(SWAP_LOOP): src/swap_loop.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf $(BUILD_DIR)
