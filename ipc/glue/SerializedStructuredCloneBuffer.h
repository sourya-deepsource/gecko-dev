/* -*- Mode: C++; tab-width: 8; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* vim: set ts=8 sts=2 et sw=2 tw=80: */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#ifndef __IPC_GLUE_SERIALIZEDSTRUCTUREDCLONEBUFFER_H__
#define __IPC_GLUE_SERIALIZEDSTRUCTUREDCLONEBUFFER_H__

#include "js/StructuredClone.h"

namespace mozilla {
template <typename...>
class Variant;

namespace detail {
template <typename...>
struct VariantTag;
}
}  // namespace mozilla

namespace mozilla {

struct SerializedStructuredCloneBuffer final {
  SerializedStructuredCloneBuffer() = default;

  SerializedStructuredCloneBuffer(SerializedStructuredCloneBuffer&&) = default;
  SerializedStructuredCloneBuffer& operator=(
      SerializedStructuredCloneBuffer&&) = default;

  SerializedStructuredCloneBuffer(const SerializedStructuredCloneBuffer&) =
      delete;
  SerializedStructuredCloneBuffer& operator=(
      const SerializedStructuredCloneBuffer& aOther) = delete;

  bool operator==(const SerializedStructuredCloneBuffer& aOther) const {
    // The copy assignment operator and the equality operator are
    // needed by the IPDL generated code. We relied on the copy
    // assignment operator at some places but we never use the
    // equality operator.
    return false;
  }

  JSStructuredCloneData data{JS::StructuredCloneScope::Unassigned};
};

}  // namespace mozilla

#endif /* __IPC_GLUE_SERIALIZEDSTRUCTUREDCLONEBUFFER_H__ */
