/*
 * Copyright (C) 2012-2013, The CyanogenMod Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
* @file ligths.cpp
*
* Handle backlight in AOSP style and forward led notification
* to the Sony light HAL.
*
*/

//#define LOG_NDEBUG 0
#define LOG_TAG "lights.cm"
#include <cutils/log.h>

#include <fcntl.h>
#include <math.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include <utils/threads.h>
#include <utils/String8.h>
#include <hardware/hardware.h>
#include <hardware/lights.h>
#include <cutils/properties.h>

#include "sony_lights.h"

static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

static android::Mutex gLightWrapperLock;
static hw_module_t *gVendorModule = 0;

static int open_lights(const hw_module_t* module, const char* name,
                       hw_device_t** device);
static int lights_device_close(hw_device_t* device);
static int lights_set_light(struct light_device_t* dev,
                            struct light_state_t const* state);

struct hw_module_methods_t lights_module_methods = {
    open: open_lights,
};

hw_module_t HAL_MODULE_INFO_SYM = {
    tag: HARDWARE_MODULE_TAG,
    version_major: 1,
    version_minor: 0,
    id: LIGHTS_HARDWARE_MODULE_ID,
    name: "Xperia Lights Wrapper",
    author: "The CyanogenMod Project",
    methods: &lights_module_methods,
    dso: NULL,
    reserved: {0},
};

typedef struct wrapper_light_device {
    light_device_t base;
    light_device_t *vendor;
} wrapper_light_device_t;

#define VENDOR_CALL(dev, func, ...) ({ \
    wrapper_light_device_t *__wrapper_dev = (wrapper_light_device_t*) dev; \
    __wrapper_dev->vendor->func(__wrapper_dev->vendor, ##__VA_ARGS__); \
})

static int check_vendor_module()
{
    int rv = 0;
    ALOGV("[%s]", __FUNCTION__);

    if (gVendorModule)
        return 0;

    rv = hw_get_module_by_class("lights", "vendor", (const hw_module_t **)&gVendorModule);
    if (rv)
        ALOGE("failed to open vendor light module");

    return rv;
}

static int lights_set_light(struct light_device_t* dev,
                     struct light_state_t const* state)
{
    ALOGV("%s->%08X->%08X", __FUNCTION__, (uintptr_t)dev, (uintptr_t)(((wrapper_light_device_t*)dev)->vendor));

    if(!dev)
        return -EINVAL;

    // Filter out the unused alpha channel
    struct light_state_t lights = *state;
    lights.color = lights.color & 0x00FFFFFF;

    return VENDOR_CALL(dev, set_light, &lights);
}

static int lights_device_close(hw_device_t* device)
{
    int ret = 0;
    wrapper_light_device_t *wrapper_dev = NULL;

    ALOGV("[%s]", __FUNCTION__);

    android::Mutex::Autolock lock(gLightWrapperLock);

    if (!device) {
        ret = -EINVAL;
        goto done;
    }

    wrapper_dev = (wrapper_light_device_t*) device;

    // nicki: backlight and the RGB LED lights are handled directly and have no
    // backing vendor device, so only close one if we actually opened it.
    if (wrapper_dev->vendor != NULL)
        wrapper_dev->vendor->common.close((hw_device_t*)wrapper_dev->vendor);
    free(wrapper_dev);

done:
    return ret;
}

static int write_int (const char *path, int value) {
    int fd;
    static int already_warned = 0;

    fd = open(path, O_RDWR);
    if (fd < 0) {
        if (already_warned == 0) {
            ALOGE("write_int failed to open %s\n", path);
                already_warned = 1;
        }
        return -errno;
    }

    char buffer[20];
    int bytes = snprintf(buffer, sizeof(buffer), "%d\n", value);
    int written = write (fd, buffer, bytes);
    close(fd);

    return written == -1 ? -errno : 0;
}

static int write_string (const char *path, const char *value) {
    int fd;
    static int already_warned = 0;

    fd = open(path, O_RDWR);
    if (fd < 0) {
        if (already_warned == 0) {
            ALOGE("write_string failed to open %s\n", path);
                already_warned = 1;
        }
        return -errno;
    }

    char buffer[20];
    int bytes = snprintf(buffer, sizeof(buffer), "%s\n", value);
    int written = write (fd, buffer, bytes);
    close(fd);

    return written == -1 ? -errno : 0;
}

static int rgb_to_brightness (struct light_state_t const* state) {
    int color = state->color & 0x00ffffff;
    return ((77*((color>>16)&0x00ff))
            + (150*((color>>8)&0x00ff)) + (29*(color&0x00ff))) >> 8;
}

#ifdef ENABLE_GAMMA_CORRECTION
static int brightness_apply_gamma (int brightness) {
    double floatbrt = (double) brightness;
    floatbrt /= 255.0;
    ALOGV("%s: brightness = %d, floatbrt = %f", __FUNCTION__, brightness, floatbrt);
    floatbrt = pow(floatbrt, 2.2);
    ALOGV("%s: gamma corrected floatbrt = %f", __FUNCTION__, floatbrt);
    floatbrt *= 255.0;
    brightness = (int) floatbrt;
    ALOGV("%s: gamma corrected brightness = %d", __FUNCTION__, brightness);
    return brightness;
}
#endif

static int get_max_brightness() {
    char value[6];
    int fd, len, max_brightness;

    if ((fd = open(MAX_BRIGHTNESS_FILE, O_RDONLY)) < 0) {
        ALOGE("[%s]: Could not open max brightness file %s: %s", __FUNCTION__,
                     MAX_BRIGHTNESS_FILE, strerror(errno));
        ALOGE("[%s]: Assume max brightness 255", __FUNCTION__);
        return 255;
    }

    if ((len = read(fd, value, sizeof(value))) <= 1) {
        ALOGE("[%s]: Could not read max brightness file %s: %s", __FUNCTION__,
                     MAX_BRIGHTNESS_FILE, strerror(errno));
        ALOGE("[%s]: Assume max brightness 255", __FUNCTION__);
        close(fd);
        return 255;
    }

    max_brightness = strtol(value, NULL, 10);
    close(fd);

    return (unsigned int) max_brightness;
}

static int lights_set_light_backlight (struct light_device_t *dev, struct light_state_t const *state) {
    int err = 0;
    int brightness = rgb_to_brightness(state);
    int max_brightness = get_max_brightness();

    if (brightness > 0) {
#ifdef ENABLE_GAMMA_CORRECTION
        brightness = brightness_apply_gamma(brightness);
#endif
        brightness = max_brightness * brightness / 255;
        if (brightness < LCD_BRIGHTNESS_MIN)
            brightness = LCD_BRIGHTNESS_MIN;
    }

    ALOGV("[%s] brightness %d max_brightness %d", __FUNCTION__, brightness, max_brightness);

    pthread_mutex_lock(&g_lock);
    err |= write_int (LCD_BACKLIGHT_FILE, brightness);
    err |= write_int (LCD_BACKLIGHT2_FILE, brightness);
#ifdef DEVICE_HAYABUSA
    err |= write_int (LOGO_BACKLIGHT_FILE, brightness);
    err |= write_int (LOGO_BACKLIGHT2_FILE, brightness);
#endif
    pthread_mutex_unlock(&g_lock);

    return err;
}

/*
 * nicki: drive the RGB notification/battery LED directly through the kernel
 * fih_led "control" interface, bypassing the fragile Sony led_deamon + vendor
 * blob + /data/LED_deamon.* FIFO path. That path races the framework's one-shot
 * light-HAL map build at boot (led_deamon isn't ready in time), leaving the
 * light permanently LIGHT_NOT_SUPPORTED. The kernel interface takes text
 * commands "<cmd> <led_id> <params...>" (led_id 0=red 1=green 2=blue):
 *   4 <led> <0-255>          set on-brightness
 *   1 <led> <0|1>            steady on/off
 *   2 <led> <0|1>            blink on/off
 *   7 <led> <onMS> <offMS>   blink timing
 */
#define LED_CONTROL_FILE "/sys/class/led/fih_led/control"

static void led_ctl(const char *cmd) {
    int fd = open(LED_CONTROL_FILE, O_WRONLY);
    if (fd < 0) {
        ALOGE("led_ctl: cannot open %s: %s", LED_CONTROL_FILE, strerror(errno));
        return;
    }
    // The kernel fih_led parser needs a trailing newline to terminate the last
    // parameter (otherwise it logs "Can't get parameter" and ignores the write).
    char line[72];
    int n = snprintf(line, sizeof(line), "%s\n", cmd);
    if (write(fd, line, n) < 0)
        ALOGE("led_ctl: write '%s' failed: %s", cmd, strerror(errno));
    close(fd);
}

static void set_led_channel(int led_id, int brightness, bool blink, int onMS, int offMS) {
    char buf[64];
    if (brightness <= 0) {
        snprintf(buf, sizeof(buf), "2 %d 0", led_id); led_ctl(buf);  /* stop blink */
        snprintf(buf, sizeof(buf), "1 %d 0", led_id); led_ctl(buf);  /* off        */
        return;
    }
    snprintf(buf, sizeof(buf), "4 %d %d", led_id, brightness); led_ctl(buf);  /* brightness */
    if (blink && onMS > 0 && offMS > 0) {
        snprintf(buf, sizeof(buf), "7 %d %d %d", led_id, onMS, offMS); led_ctl(buf);
        snprintf(buf, sizeof(buf), "2 %d 1", led_id); led_ctl(buf);  /* blink on */
    } else {
        snprintf(buf, sizeof(buf), "2 %d 0", led_id); led_ctl(buf);  /* stop blink   */
        snprintf(buf, sizeof(buf), "1 %d 1", led_id); led_ctl(buf);  /* steady on    */
    }
}

static int lights_set_light_led(struct light_device_t * /*dev*/,
                                struct light_state_t const *state) {
    int color = state->color & 0x00ffffff;
    int red   = (color >> 16) & 0xff;
    int green = (color >> 8)  & 0xff;
    int blue  =  color        & 0xff;
    bool blink = (state->flashMode == LIGHT_FLASH_TIMED ||
                  state->flashMode == LIGHT_FLASH_HARDWARE);
    int onMS  = blink ? state->flashOnMS  : 0;
    int offMS = blink ? state->flashOffMS : 0;

    ALOGV("%s: color=%08x flash=%d on=%d off=%d", __FUNCTION__,
            state->color, state->flashMode, onMS, offMS);

    pthread_mutex_lock(&g_lock);
    set_led_channel(0, red,   blink, onMS, offMS);
    set_led_channel(1, green, blink, onMS, offMS);
    set_led_channel(2, blue,  blink, onMS, offMS);
    pthread_mutex_unlock(&g_lock);
    return 0;
}

static int open_lights(const hw_module_t* module, const char* name,
                       hw_device_t** device)
{
    int rv = 0;
    int (*set_light)(struct light_device_t* dev,
                     struct light_state_t const* state);

    wrapper_light_device_t* light_device = NULL;

    android::Mutex::Autolock lock(gLightWrapperLock);

    ALOGV("lights device open");

    if (name != NULL) {
        light_device = (wrapper_light_device_t*)malloc(sizeof(*light_device));
        if (!light_device) {
            ALOGE("light_device allocation fail");
            rv = -ENOMEM;
            goto fail;
        }
        memset(light_device, 0, sizeof(*light_device));
        light_device->vendor = NULL;

        // nicki: backlight (direct LCD sysfs) and the RGB notification/battery LED
        // (direct kernel fih_led, see lights_set_light_led) are handled in-process
        // and need NO vendor module -- this avoids the fragile led_deamon + vendor
        // blob + /data FIFO path that races the one-shot light-HAL map build at
        // boot and leaves the LED permanently unsupported. Only LIGHT_ID_BUTTONS
        // still forwards to the Sony blob (nicki has no button light, so that open
        // simply fails and the light is reported unsupported, which is correct).
        if (0 == strcmp(LIGHT_ID_BACKLIGHT, name)) {
            set_light = lights_set_light_backlight;
        } else if (0 == strcmp(LIGHT_ID_NOTIFICATIONS, name) ||
                   0 == strcmp(LIGHT_ID_BATTERY, name) ||
                   0 == strcmp(LIGHT_ID_ATTENTION, name)) {
            set_light = lights_set_light_led;
        } else if (0 == strcmp(LIGHT_ID_BUTTONS, name)) {
            if (check_vendor_module()) {
                rv = -EINVAL;
                goto fail;
            }
            if (rv = gVendorModule->methods->open((const hw_module_t*)gVendorModule,
                    name, (hw_device_t**)&(light_device->vendor))) {
                ALOGE("vendor light open fail");
                goto fail;
            }
            set_light = lights_set_light;
        } else {
            free(light_device);
            return -EINVAL;
        }

        light_device->base.common.tag     = HARDWARE_DEVICE_TAG;
        light_device->base.common.version = 0;
        light_device->base.common.module  = (hw_module_t *)(module);
        light_device->base.common.close   = lights_device_close;
        light_device->base.set_light      = set_light;

        *device = (struct hw_device_t*)light_device;
    }

    return rv;

fail:
    if (light_device) {
        free(light_device);
        light_device = NULL;
    }
    *device = NULL;

    return rv;
}
