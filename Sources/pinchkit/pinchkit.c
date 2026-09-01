// pinchkit — global pinch detection, extracted from the validated pinchprobe
// spike (see Sources/pinchprobe and CLAUDE.md for the validation data).

#include "pinchkit.h"

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <stddef.h>

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

static CFMutableArrayRef gDevices = NULL;
static pinchkit_handler gHandler = NULL;

// --- detector (thresholds validated 2026-09-01, 18/18 pinches, 0 false pos) --

#define RING 16
#define LOOKBACK 12          // frames (~90ms at 125Hz)
#define SPREAD_DELTA 0.035f  // 0.05 missed short pinches; swipes measure ~0.01
#define MAX_DRIFT 0.10f

static int runCount = -1;
static long runLen = 0;
static int armed = 1;
static float rSpread[RING], rCx[RING], rCy[RING];

static void detect(int n, float spread, float cx, float cy) {
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
            armed = 0;
            if (gHandler) gHandler(dSpread > 0);
        }
    }
    runLen++;
}

static int frameCallback(MTDeviceRef dev, MTTouch *touches, int n, double ts, int frame) {
    (void)dev; (void)ts; (void)frame;
    if (n == 0) { armed = 1; runCount = -1; runLen = 0; return 0; }

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

    detect(n, spread, cx, cy);
    return 0;
}

int pinchkit_start(pinchkit_handler handler) {
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW);
    if (!handle) return -1;

    MTDeviceCreateList = dlsym(handle, "MTDeviceCreateList");
    MTRegisterContactFrameCallback = dlsym(handle, "MTRegisterContactFrameCallback");
    MTDeviceStart = dlsym(handle, "MTDeviceStart");
    MTDeviceStop = dlsym(handle, "MTDeviceStop");
    if (!MTDeviceCreateList || !MTRegisterContactFrameCallback || !MTDeviceStart || !MTDeviceStop)
        return -1;

    gHandler = handler;
    gDevices = MTDeviceCreateList();
    CFIndex count = gDevices ? CFArrayGetCount(gDevices) : 0;
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef dev = (MTDeviceRef)CFArrayGetValueAtIndex(gDevices, i);
        MTRegisterContactFrameCallback(dev, frameCallback);
        MTDeviceStart(dev, 0);
    }
    return (int)count;
}

void pinchkit_stop(void) {
    if (!gDevices) return;
    CFIndex count = CFArrayGetCount(gDevices);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceStop((MTDeviceRef)CFArrayGetValueAtIndex(gDevices, i));
    }
    gDevices = NULL;
    gHandler = NULL;
}
