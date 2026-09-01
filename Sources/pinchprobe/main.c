// pinchprobe — M5 spike, v2: live pinch detection.
// Reads raw trackpad touches via the private MultitouchSupport framework and
// runs the suparpad pinch detector, printing *** PINCH-CLOSE/OPEN *** events.
//
// Detector (thresholds derived from real capture on this machine, 2026-09-01):
//   - consider only frames with >= 3 fingers; reset the run when count changes
//     (spread jumps discontinuously when a finger lands/lifts)
//   - slide a 12-frame (~90ms @ 125Hz) window over a stable run
//   - PINCH-CLOSE: spread delta <= -0.05 with centroid drift <= 0.10
//   - PINCH-OPEN:  spread delta >= +0.05 with centroid drift <= 0.10
//   - one event per touch session; re-arm only when all fingers lift
// Real pinches measured at |delta| ~0.06-0.10 per window; a 4-finger swipe
// measured ~0.01 with drift ~0.14 — clean separation.
//
// Usage: pinchprobe [seconds] [-v]   (-v also logs every touch frame)
//
// Private API resolved at runtime via dlopen (the framework binary lives in the
// dyld shared cache, so there is nothing to link against at build time).

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { float x, y; } mtPoint;
typedef struct { mtPoint pos, vel; } mtReadout;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;
    int fingerId;
    int handId;
    mtReadout normalized;
    float zTotal;
    int field9;
    float angle;
    float majorAxis;
    float minorAxis;
    mtReadout mm;
    int field14;
    int field15;
    float zDensity;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(MTDeviceRef, MTTouch *, int, double, int);

static CFMutableArrayRef (*MTDeviceCreateList)(void);
static void (*MTRegisterContactFrameCallback)(MTDeviceRef, MTContactCallbackFunction);
static void (*MTDeviceStart)(MTDeviceRef, int);
static void (*MTDeviceStop)(MTDeviceRef);

static int verbose = 0;

// --- detector ---------------------------------------------------------------

#define RING 16
#define LOOKBACK 12          // frames (~90ms at 125Hz)
#define SPREAD_DELTA 0.05f   // min |spread change| across the window
#define MAX_DRIFT 0.10f      // max centroid travel across the window

static int runCount = -1;    // finger count of the current stable run
static long runLen = 0;      // frames seen in the current run
static int armed = 1;        // one event per touch session
static float rSpread[RING], rCx[RING], rCy[RING];

static void detect(int n, float spread, float cx, float cy, double ts) {
    if (n < 3) { runCount = -1; runLen = 0; return; }
    if (n != runCount) { runCount = n; runLen = 0; }

    long idx = runLen % RING;
    rSpread[idx] = spread; rCx[idx] = cx; rCy[idx] = cy;

    if (armed && runLen >= LOOKBACK) {
        long back = (runLen - LOOKBACK) % RING;
        float dSpread = spread - rSpread[back];
        float dx = cx - rCx[back], dy = cy - rCy[back];
        float drift = sqrtf(dx * dx + dy * dy);
        if (drift <= MAX_DRIFT && fabsf(dSpread) >= SPREAD_DELTA) {
            printf("*** PINCH-%s *** t=%.3f fingers=%d dSpread=%+.3f drift=%.3f\n",
                   dSpread < 0 ? "CLOSE" : "OPEN", ts, n, dSpread, drift);
            fflush(stdout);
            armed = 0;
        }
    }
    runLen++;
}

// --- MT callback ------------------------------------------------------------

static int lastN = -1;

static int frameCallback(MTDeviceRef dev, MTTouch *touches, int n, double ts, int frame) {
    (void)dev; (void)frame;
    if (n == 0) { armed = 1; runCount = -1; runLen = 0; }
    if (n != lastN && !verbose) {
        printf("t=%9.3f fingers=%d\n", ts, n);
        fflush(stdout);
        lastN = n;
    }
    if (n == 0) return 0;

    float cx = 0, cy = 0;
    for (int i = 0; i < n; i++) { cx += touches[i].normalized.pos.x; cy += touches[i].normalized.pos.y; }
    cx /= n; cy /= n;
    float spread = 0;
    for (int i = 0; i < n; i++) {
        float dx = touches[i].normalized.pos.x - cx;
        float dy = touches[i].normalized.pos.y - cy;
        spread += sqrtf(dx * dx + dy * dy);
    }
    spread /= n;

    if (verbose) {
        printf("t=%9.3f fingers=%d spread=%.4f centroid=(%.3f,%.3f)\n", ts, n, spread, cx, cy);
        fflush(stdout);
    }
    detect(n, spread, cx, cy, ts);
    return 0;
}

int main(int argc, char **argv) {
    int seconds = 10;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-v") == 0) verbose = 1;
        else seconds = atoi(argv[i]);
    }

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW);
    if (!handle) {
        fprintf(stderr, "FAIL: dlopen MultitouchSupport: %s\n", dlerror());
        return 1;
    }
    MTDeviceCreateList = dlsym(handle, "MTDeviceCreateList");
    MTRegisterContactFrameCallback = dlsym(handle, "MTRegisterContactFrameCallback");
    MTDeviceStart = dlsym(handle, "MTDeviceStart");
    MTDeviceStop = dlsym(handle, "MTDeviceStop");
    if (!MTDeviceCreateList || !MTRegisterContactFrameCallback || !MTDeviceStart || !MTDeviceStop) {
        fprintf(stderr, "FAIL: dlsym missing MT symbols\n");
        return 1;
    }

    CFMutableArrayRef devices = MTDeviceCreateList();
    CFIndex count = devices ? CFArrayGetCount(devices) : 0;
    printf("multitouch devices found: %ld\n", (long)count);
    if (count == 0) {
        fprintf(stderr, "No devices. Either no trackpad, or Input Monitoring permission "
                        "is missing for the terminal running this.\n");
        return 2;
    }

    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(devices, i);
        MTRegisterContactFrameCallback(dev, frameCallback);
        MTDeviceStart(dev, 0);
    }
    printf("detecting for %d seconds — pinch away (scroll/swipe too, to test false positives)...\n",
           seconds);
    fflush(stdout);

    CFRunLoopRunInMode(kCFRunLoopDefaultMode, seconds, false);

    for (CFIndex i = 0; i < count; i++) {
        MTDeviceStop((MTDeviceRef)CFArrayGetValueAtIndex(devices, i));
    }
    printf("done.\n");
    return 0;
}
