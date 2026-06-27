// Subscribe to the accelerometer through the FRAMEWORK (ASensorManager ->
// SensorService -> sensors HAL) and print events. This is the real app path,
// so if events arrive here, auto-rotate / CPU-Z will work too.

#include <android/sensor.h>
#include <android/looper.h>
#include <unistd.h>
#include <stdio.h>

int main() {
    ASensorManager* mgr = ASensorManager_getInstanceForPackage("nicki.sensorpoll");
    if (!mgr) mgr = ASensorManager_getInstance();
    if (!mgr) { printf("no ASensorManager\n"); return 1; }

    const ASensor* accel = ASensorManager_getDefaultSensor(mgr, ASENSOR_TYPE_ACCELEROMETER);
    printf("accel=%p name='%s'\n", accel, accel ? ASensor_getName(accel) : "(null)");
    if (!accel) { printf("no default accelerometer\n"); return 1; }

    ALooper* looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
    ASensorEventQueue* q =
        ASensorManager_createEventQueue(mgr, looper, 3, NULL, NULL);
    if (!q) { printf("createEventQueue failed\n"); return 1; }

    int er = ASensorEventQueue_enableSensor(q, accel);
    int rr = ASensorEventQueue_setEventRate(q, accel, 200000); // 200 ms
    printf("enableSensor=%d setEventRate=%d\n", er, rr);

    int got = 0;
    for (int i = 0; i < 25 && got < 5; i++) {
        int id = ALooper_pollAll(1000, NULL, NULL, NULL); // 1 s timeout
        ASensorEvent ev;
        while (ASensorEventQueue_getEvents(q, &ev, 1) > 0) {
            printf("EVENT type=%d  accel=[% .3f % .3f % .3f]\n",
                   ev.type, ev.acceleration.x, ev.acceleration.y, ev.acceleration.z);
            got++;
        }
        if (id == ALOOPER_POLL_TIMEOUT) printf("  (poll %d timed out, no event)\n", i);
    }
    printf(got ? "RESULT: events FLOW (%d)\n" : "RESULT: NO events (%d)\n", got);
    ASensorEventQueue_disableSensor(q, accel);
    ASensorManager_destroyEventQueue(mgr, q);
    return 0;
}
