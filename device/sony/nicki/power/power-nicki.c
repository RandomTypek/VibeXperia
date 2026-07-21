/*
 * Copyright (C) 2026 The LineageOS Project
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

/*
 * nicki (Sony Xperia M, MSM8227) legacy power HAL -- power.msm8960.so.
 *
 * The LineageOS PerformanceManagerService applies a performance profile with
 * PowerManagerInternal.powerHint(POWER_HINT_SET_PROFILE, <profile>), which the
 * android.hardware.power@1.0 passthrough forwards to this module's powerHint().
 *
 * Pie dropped the legacy QCOM power HAL from the tree, so hw_get_module() was
 * falling back to the generic power.default.so (a no-op) -> switching profiles
 * did nothing. Provide a minimal legacy power_module whose only job is to drive
 * the profiles by writing the cpufreq scaling limits on both (always-online)
 * Cortex-A5 cores DIRECTLY -- nicki has no perfd/mpdecision, so the stock 8960
 * perf-daemon opcode approach is a no-op here. Ported from the working 15.1
 * device/qcom/common/power/power-8960.c.
 *
 * hw_get_module() tries power.qcom.so first (ro.hardware/ro.product.board ==
 * "qcom"); that isn't installed, so it loads this power.msm8960.so via the
 * ro.board.platform=msm8960 variant, ahead of the fallback power.default.so.
 */

#define LOG_TAG "nicki-PowerHAL"

#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdint.h>

#include <log/log.h>
#include <hardware/hardware.h>
#include <hardware/power.h>

/* LineageOS performance-profile hint + profile ids (framework: 0x00000111). */
#define POWER_HINT_SET_PROFILE      0x00000111
#define PROFILE_POWER_SAVE          0
#define PROFILE_BALANCED            1
#define PROFILE_HIGH_PERFORMANCE    2

#define CPU0_MAX "/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
#define CPU1_MAX "/sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq"
#define CPU0_MIN "/sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
#define CPU1_MIN "/sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq"

#define FREQ_MAX     "1458000"
#define FREQ_MIN     "192000"
#define FREQ_PWRSAVE "1026000"   /* cap ~70% of max to save power     */
#define FREQ_PERF    "594000"    /* floor so the CPU stays responsive */

static int current_power_profile = PROFILE_BALANCED;

static void cpufreq_write(const char *path, const char *val) {
    int fd = open(path, O_WRONLY);
    if (fd < 0) {
        ALOGE("%s: open %s failed: %s", __func__, path, strerror(errno));
        return;
    }
    if (write(fd, val, strlen(val)) < 0)
        ALOGE("%s: write %s=%s failed: %s", __func__, path, val, strerror(errno));
    close(fd);
}

static void set_power_profile(int profile) {
    if (profile == current_power_profile)
        return;

    switch (profile) {
    case PROFILE_POWER_SAVE:
        cpufreq_write(CPU0_MIN, FREQ_MIN);
        cpufreq_write(CPU1_MIN, FREQ_MIN);
        cpufreq_write(CPU0_MAX, FREQ_PWRSAVE);
        cpufreq_write(CPU1_MAX, FREQ_PWRSAVE);
        ALOGD("%s: set powersave", __func__);
        break;
    case PROFILE_HIGH_PERFORMANCE:
        cpufreq_write(CPU0_MAX, FREQ_MAX);
        cpufreq_write(CPU1_MAX, FREQ_MAX);
        cpufreq_write(CPU0_MIN, FREQ_PERF);
        cpufreq_write(CPU1_MIN, FREQ_PERF);
        ALOGD("%s: set performance", __func__);
        break;
    case PROFILE_BALANCED:
    default:
        cpufreq_write(CPU0_MAX, FREQ_MAX);
        cpufreq_write(CPU1_MAX, FREQ_MAX);
        cpufreq_write(CPU0_MIN, FREQ_MIN);
        cpufreq_write(CPU1_MIN, FREQ_MIN);
        profile = PROFILE_BALANCED;
        ALOGD("%s: set balanced", __func__);
        break;
    }

    current_power_profile = profile;
}

static void power_init(struct power_module *module __attribute__((unused))) {
}

static void power_set_interactive(struct power_module *module __attribute__((unused)),
                                  int on __attribute__((unused))) {
}

static void power_hint(struct power_module *module __attribute__((unused)),
                       power_hint_t hint, void *data) {
    if ((int)hint == POWER_HINT_SET_PROFILE) {
        /* The @1.0 passthrough passes NULL for data == 0, i.e. PROFILE_POWER_SAVE. */
        set_power_profile(data ? *(int32_t *)data : PROFILE_POWER_SAVE);
    }
}

static struct hw_module_methods_t power_module_methods = {
    .open = NULL,
};

struct power_module HAL_MODULE_INFO_SYM = {
    .common = {
        .tag = HARDWARE_MODULE_TAG,
        .module_api_version = POWER_MODULE_API_VERSION_0_2,
        .hal_api_version = HARDWARE_HAL_API_VERSION,
        .id = POWER_HARDWARE_MODULE_ID,
        .name = "nicki Power HAL",
        .author = "LineageOS",
        .methods = &power_module_methods,
    },
    .init = power_init,
    .setInteractive = power_set_interactive,
    .powerHint = power_hint,
};
