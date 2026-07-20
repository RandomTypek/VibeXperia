#
# Copyright (C) 2013-2016 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Board device path
DEVICE_PATH := device/sony/nicki

# Low-RAM: build jemalloc in its svelte (low-memory) configuration -- smaller
# arenas / less per-process native heap overhead. Pairs with the framework
# low-RAM mode in product/lowram.mk. nicki has ~880 MB usable RAM.
MALLOC_SVELTE := true

# Board device headers
TARGET_SPECIFIC_HEADER_PATH := $(DEVICE_PATH)/include

# Board device elements
include $(DEVICE_PATH)/PlatformConfig.mk
include $(DEVICE_PATH)/board/*.mk

# Board device vendor
-include vendor/sony/nicki/BoardConfigVendor.mk

# nicki: disable the liblights HAL gamma (pow 2.2). Pie's brightness slider
# already applies its own perceptual gamma (BrightnessController convertGammaToLinear),
# so the HAL gamma double-corrects -> bottom ~half of the slider maps to minimum
# backlight (dead zone). Oreo/15.1 had a LINEAR slider so the single HAL gamma was
# correct there; on Pie it is redundant. Leaves the framework slider as the sole gamma.
TARGET_DISPLAY_GAMMA_DISABLED := true
