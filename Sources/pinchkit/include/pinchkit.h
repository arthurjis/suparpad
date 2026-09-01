#ifndef PINCHKIT_H
#define PINCHKIT_H

// Global trackpad pinch detection over the private MultitouchSupport
// framework. Thresholds validated on this machine — see CLAUDE.md.

// is_open: 0 = pinch-close (fingers together), 1 = pinch-open (spread).
// Called on a MultitouchSupport background thread — dispatch to main.
typedef void (*pinchkit_handler)(int is_open);

// Returns device count (>0) on success, 0 if no devices (missing Input
// Monitoring permission or no trackpad), -1 on framework load failure.
int pinchkit_start(pinchkit_handler handler);
void pinchkit_stop(void);

#endif
