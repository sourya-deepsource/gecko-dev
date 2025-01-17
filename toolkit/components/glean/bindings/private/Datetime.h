/* -*- Mode: C++; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* vim: set ts=8 sts=2 et sw=2 tw=80: */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef mozilla_glean_GleanDatetime_h
#define mozilla_glean_GleanDatetime_h

#include "mozilla/Maybe.h"
#include "nsIGleanMetrics.h"
#include "nsString.h"
#include "prtime.h"

namespace mozilla::glean {

namespace impl {
extern "C" {
void fog_datetime_set(uint32_t aId, int32_t aYear, uint32_t aMonth,
                      uint32_t aDay, uint32_t aHour, uint32_t aMinute,
                      uint32_t aSecond, uint32_t aNano, int32_t aOffsetSeconds);
uint32_t fog_datetime_test_has_value(uint32_t aId, const char* aStorageName);
void fog_datetime_test_get_value(uint32_t aId, const char* aStorageName,
                                 nsACString& aValue);
}

class DatetimeMetric {
 public:
  constexpr explicit DatetimeMetric(uint32_t aId) : mId(aId) {}

  /*
   * Set the datetime to the provided value, or the local now.
   *
   * @param amount The date value to set.
   */
  void Set(const PRExplodedTime* aValue = nullptr) const {
    PRExplodedTime exploded;
    if (!aValue) {
      PR_ExplodeTime(PR_Now(), PR_LocalTimeParameters, &exploded);
    } else {
      exploded = *aValue;
    }

    int32_t offset =
        exploded.tm_params.tp_gmt_offset + exploded.tm_params.tp_dst_offset;
    fog_datetime_set(mId, exploded.tm_year, exploded.tm_month + 1,
                     exploded.tm_mday, exploded.tm_hour, exploded.tm_min,
                     exploded.tm_sec, exploded.tm_usec * 1000, offset);
  }

  /**
   * **Test-only API**
   *
   * Gets the currently stored value as an integer.
   *
   * This function will attempt to await the last parent-process task (if any)
   * writing to the the metric's storage engine before returning a value.
   * This function will not wait for data from child processes.
   *
   * This doesn't clear the stored value.
   * Parent process only. Panics in child processes.
   *
   * @return value of the stored metric, or Nothing() if there is no value.
   */
  Maybe<nsCString> TestGetValue(const char* aStorageName) const {
    if (!fog_datetime_test_has_value(mId, aStorageName)) {
      return Nothing();
    }
    nsCString ret;
    fog_datetime_test_get_value(mId, aStorageName, ret);
    return Some(ret);
  }

 private:
  const uint32_t mId;
};
}  // namespace impl

class GleanDatetime final : public nsIGleanDatetime {
 public:
  NS_DECL_ISUPPORTS
  NS_DECL_NSIGLEANDATETIME

  explicit GleanDatetime(uint32_t aId) : mDatetime(aId){};

 private:
  virtual ~GleanDatetime() = default;

  const impl::DatetimeMetric mDatetime;
};

}  // namespace mozilla::glean

#endif /* mozilla_glean_GleanDatetime_h */
