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
 * nicki: minimal vendor.lineage.power@1.0 (ILineagePower) service.
 *
 * LineageOS 15.1's PowerManagerService queries performance-profile support via
 * vendor::lineage::power::V1_0::ILineagePower::getService()->getFeature(). nicki
 * uses the legacy passthrough power HAL (power.qcom.so) which 15.1's framework no
 * longer reads for this, so without this service getService() returns null and
 * the Battery > performance-profile picker is hidden. We answer SUPPORTED_PROFILES
 * with 3 (power save / balanced / performance) -- matching power-8960.c's
 * get_number_of_profiles(). Profile *switching* still flows through the standard
 * IPower::powerHint(SET_PROFILE) into power.qcom.so set_power_profile().
 */

#define LOG_TAG "vendor.lineage.power@1.0-service.nicki"

#include <android-base/logging.h>
#include <hidl/HidlTransportSupport.h>
#include <vendor/lineage/power/1.0/ILineagePower.h>

using android::OK;
using android::sp;
using android::status_t;
using android::hardware::configureRpcThreadpool;
using android::hardware::joinRpcThreadpool;
using android::hardware::Return;
using vendor::lineage::power::V1_0::ILineagePower;
using vendor::lineage::power::V1_0::LineageFeature;

namespace {

class LineagePower : public ILineagePower {
  public:
    Return<int32_t> getFeature(LineageFeature feature) override {
        switch (feature) {
            case LineageFeature::SUPPORTED_PROFILES:
                return 3;  // power save / balanced / performance
            default:
                return -1;
        }
    }
};

}  // anonymous namespace

int main() {
    configureRpcThreadpool(1, true /* callerWillJoin */);

    sp<ILineagePower> service = new LineagePower();
    status_t status = service->registerAsService();
    if (status != OK) {
        LOG(ERROR) << "Could not register vendor.lineage.power@1.0 service: " << status;
        return 1;
    }

    LOG(INFO) << "vendor.lineage.power@1.0 service (nicki) ready";
    joinRpcThreadpool();
    return 1;  // joinRpcThreadpool should never return
}
