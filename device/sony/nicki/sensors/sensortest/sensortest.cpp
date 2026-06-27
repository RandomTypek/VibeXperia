// Standalone probe for the proprietary nicki sensors sub-HAL (sensors.default.so).
// Runs in its OWN process so a crash here cannot take down system_server.
// Prints what the blob's get_sensors_list/open return, and the on-wire stride of
// its sensor_t, so we can determine the exact ABI vs Oreo's hardware/sensors.h.

#include <dlfcn.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <inttypes.h>
#include <hardware/hardware.h>
#include <hardware/sensors.h>

#define STEP(...) do { fprintf(stderr, "[sensortest] " __VA_ARGS__); fprintf(stderr, "\n"); fflush(stderr); } while (0)

int main(int argc, char** argv) {
    const char* path = (argc > 1) ? argv[1] : "/system/lib/hw/sensors.default.so";
    STEP("Oreo sizeof(sensor_t)=%zu sizeof(sensors_poll_device_t)=%zu sizeof(sensors_poll_device_1_t)=%zu",
         sizeof(struct sensor_t), sizeof(struct sensors_poll_device_t), sizeof(sensors_poll_device_1_t));

    STEP("dlopen(%s)", path);
    void* h = dlopen(path, RTLD_NOW);
    if (!h) { STEP("dlopen FAILED: %s", dlerror()); return 1; }

    STEP("dlsym(HAL_MODULE_INFO_SYM)");
    struct sensors_module_t* mod = (struct sensors_module_t*) dlsym(h, HAL_MODULE_INFO_SYM_AS_STR);
    if (!mod) { STEP("no HMI symbol: %s", dlerror()); return 1; }
    STEP("module name='%s' author='%s' version_major=%d version_minor=%d",
         mod->common.name ? mod->common.name : "(null)",
         mod->common.author ? mod->common.author : "(null)",
         mod->common.version_major, mod->common.version_minor);

    // NOTE: framework order is open() BEFORE get_sensors_list(). multihal's
    // get_sensors_list uses state set up by open(), so open first.
    STEP("call module open() (BEFORE list, matching framework order)");
    struct hw_device_t* predev = NULL;
    int prerc = mod->common.methods->open((const struct hw_module_t*)mod,
                                          SENSORS_HARDWARE_POLL, &predev);
    STEP("open() rc=%d dev=%p", prerc, (void*)predev);

    STEP("call get_sensors_list");
    struct sensor_t const* list = NULL;
    int count = mod->get_sensors_list(mod, &list);
    STEP("get_sensors_list returned count=%d list=%p", count, (void*)list);
    if (count <= 0 || !list) { STEP("no sensors / null list"); }

    // Print each sensor reading fields at OREO offsets. Also dump the raw 80 bytes
    // around each element so we can spot the real stride.
    for (int i = 0; i < count && i < 16; i++) {
        const struct sensor_t* s = &list[i];   // indexed with Oreo sizeof(sensor_t)
        STEP("--- sensor[%d] @ %p (oreo-stride) ---", i, (void*)s);
        STEP("  name=%p vendor=%p", (void*)s->name, (void*)s->vendor);
        STEP("  name='%s'", s->name ? s->name : "(null)");
        STEP("  vendor='%s'", s->vendor ? s->vendor : "(null)");
        STEP("  version=%d handle=%d type=%d", s->version, s->handle, s->type);
        STEP("  maxRange=%f resolution=%f power=%f minDelay=%d",
             s->maxRange, s->resolution, s->power, s->minDelay);
        STEP("  fifoReservedEventCount=%u fifoMaxEventCount=%u",
             s->fifoReservedEventCount, s->fifoMaxEventCount);
        STEP("  stringType=%p requiredPermission=%p maxDelay=%d flags=%u",
             (void*)s->stringType, (void*)s->requiredPermission, (int)s->maxDelay, s->flags);
    }

    // Raw dump of the list memory so we can compute the actual stride independent of struct layout.
    if (count > 0 && list) {
        const uint8_t* base = (const uint8_t*) list;
        STEP("=== raw dump of list memory (first %d bytes, 8/line) ===", (count < 4 ? count : 4) * 80);
        int dumpBytes = (count < 4 ? count : 4) * 80;
        for (int off = 0; off < dumpBytes; off += 8) {
            fprintf(stderr, "[sensortest] +%04d:", off);
            for (int b = 0; b < 8; b++) fprintf(stderr, " %02x", base[off+b]);
            fprintf(stderr, "\n");
        }
        fflush(stderr);
    }

    struct hw_device_t* dev = predev;
    if (!dev) { STEP("open failed earlier, stop"); return 1; }
    STEP("dev->version=0x%08x (DEVICE_API_VERSION_1_0=0x%08x 1_3=0x%08x)",
         dev->version, SENSORS_DEVICE_API_VERSION_1_0, SENSORS_DEVICE_API_VERSION_1_3);

    // Exercise the data path: activate + setDelay + timed poll on every sensor.
    sensors_poll_device_1_t* d1 = (sensors_poll_device_1_t*) dev;
    for (int i = 0; i < count; i++) {
        int h = list[i].handle;
        STEP("activate(handle=%d '%s')", h, list[i].name ? list[i].name : "?");
        int a = d1->activate(&d1->v0, h, 1);
        STEP("  activate rc=%d", a);
        if (d1->v0.setDelay) {
            int sd = d1->v0.setDelay(&d1->v0, h, 200000000LL); // 200ms
            STEP("  setDelay rc=%d", sd);
        }
    }

    STEP("poll for events (alarm 5s timeout)...");
    alarm(5);  // SIGALRM aborts a blocking poll so the probe can't hang
    sensors_event_t ev[8];
    for (int round = 0; round < 3; round++) {
        int n = d1->v0.poll(&d1->v0, ev, 8);
        STEP("poll round %d returned n=%d", round, n);
        for (int j = 0; j < n && j < 8; j++) {
            STEP("  event: sensor=%d type=%d  data=[%f, %f, %f]",
                 ev[j].sensor, ev[j].type, ev[j].data[0], ev[j].data[1], ev[j].data[2]);
        }
        if (n <= 0) break;
    }
    alarm(0);
    STEP("DONE (no crash)");
    return 0;
}
