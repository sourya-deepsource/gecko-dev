/* clang-format off */
/* -*- Mode: Objective-C++; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* clang-format on */
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

#include "Accessible-inl.h"
#include "HyperTextAccessible-inl.h"
#include "mozilla/a11y/PDocAccessible.h"
#include "nsCocoaUtils.h"
#include "nsIPersistentProperties2.h"
#include "nsObjCExceptions.h"
#include "TextLeafAccessible.h"

#import "mozTextAccessible.h"
#import "GeckoTextMarker.h"
#import "MOXTextMarkerDelegate.h"

using namespace mozilla;
using namespace mozilla::a11y;

inline bool ToNSRange(id aValue, NSRange* aRange) {
  MOZ_ASSERT(aRange, "aRange is nil");

  if ([aValue isKindOfClass:[NSValue class]] &&
      strcmp([(NSValue*)aValue objCType], @encode(NSRange)) == 0) {
    *aRange = [aValue rangeValue];
    return true;
  }

  return false;
}

inline NSString* ToNSString(id aValue) {
  if ([aValue isKindOfClass:[NSString class]]) {
    return aValue;
  }

  return nil;
}

@interface mozTextAccessible ()
- (long)textLength;
- (BOOL)isReadOnly;
- (NSString*)text;
- (GeckoTextMarkerRange)selection;
- (GeckoTextMarkerRange)textMarkerRangeFromRange:(NSValue*)range;
@end

@implementation mozTextAccessible

- (NSString*)moxTitle {
  return @"";
}

- (id)moxValue {
  // Apple's SpeechSynthesisServer expects AXValue to return an AXStaticText
  // object's AXSelectedText attribute. See bug 674612 for details.
  // Also if there is no selected text, we return the full text.
  // See bug 369710 for details.
  if ([[self moxRole] isEqualToString:NSAccessibilityStaticTextRole]) {
    NSString* selectedText = [self moxSelectedText];
    return (selectedText && [selectedText length]) ? selectedText : [self text];
  }

  return [self text];
}

- (id)moxRequired {
  return @([self stateWithMask:states::REQUIRED] != 0);
}

- (NSString*)moxInvalid {
  if ([self stateWithMask:states::INVALID] != 0) {
    // If the attribute exists, it has one of four values: true, false,
    // grammar, or spelling. We query the attribute value here in order
    // to find the correct string to return.
    if (Accessible* acc = mGeckoAccessible.AsAccessible()) {
      HyperTextAccessible* text = acc->AsHyperText();
      if (!text || !text->IsTextRole()) {
        // we can't get the attribute, but we should still respect the
        // invalid state flag
        return @"true";
      }
      nsAutoString invalidStr;
      nsCOMPtr<nsIPersistentProperties> attributes =
          text->DefaultTextAttributes();
      nsAccUtils::GetAccAttr(attributes, nsGkAtoms::invalid, invalidStr);
      if (invalidStr.IsEmpty()) {
        // if the attribute had no value, we should still respect the
        // invalid state flag.
        return @"true";
      }
      return nsCocoaUtils::ToNSString(invalidStr);
    } else {
      ProxyAccessible* proxy = mGeckoAccessible.AsProxy();
      // Similar to the acc case above, we iterate through our attributes
      // to find the value for `invalid`.
      AutoTArray<Attribute, 10> attrs;
      proxy->DefaultTextAttributes(&attrs);
      for (size_t i = 0; i < attrs.Length(); i++) {
        if (attrs.ElementAt(i).Name() == "invalid") {
          nsString invalidStr = attrs.ElementAt(i).Value();
          if (invalidStr.IsEmpty()) {
            break;
          }
          return nsCocoaUtils::ToNSString(invalidStr);
        }
      }
      // if we iterated through our attributes and didn't find `invalid`,
      // or if the invalid attribute had no value, we should still respect
      // the invalid flag and return true.
      return @"true";
    }
  }
  // If the flag is not set, we return false.
  return @"false";
}

- (NSNumber*)moxInsertionPointLineNumber {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  int32_t lineNumber = -1;
  if (mGeckoAccessible.IsAccessible()) {
    if (HyperTextAccessible* textAcc =
            mGeckoAccessible.AsAccessible()->AsHyperText()) {
      lineNumber = textAcc->CaretLineNumber() - 1;
    }
  } else {
    lineNumber = mGeckoAccessible.AsProxy()->CaretLineNumber() - 1;
  }

  return (lineNumber >= 0) ? [NSNumber numberWithInt:lineNumber] : nil;
}

- (NSString*)moxSubrole {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  if (mRole == roles::PASSWORD_TEXT) {
    return NSAccessibilitySecureTextFieldSubrole;
  }

  if (mRole == roles::ENTRY) {
    Accessible* acc = mGeckoAccessible.AsAccessible();
    ProxyAccessible* proxy = mGeckoAccessible.AsProxy();
    if ((acc && acc->IsSearchbox()) || (proxy && proxy->IsSearchbox())) {
      return @"AXSearchField";
    }
  }

  return nil;
}

- (NSNumber*)moxNumberOfCharacters {
  return @([self textLength]);
}

- (NSString*)moxSelectedText {
  GeckoTextMarkerRange selection = [self selection];
  if (!selection.IsValid()) {
    return nil;
  }

  return selection.Text();
}

- (NSValue*)moxSelectedTextRange {
  GeckoTextMarkerRange selection = [self selection];
  if (!selection.IsValid()) {
    return nil;
  }

  GeckoTextMarkerRange fromStartToSelection(
      GeckoTextMarker(mGeckoAccessible, 0), selection.mStart);

  return [NSValue valueWithRange:NSMakeRange(fromStartToSelection.Length(),
                                             selection.Length())];
}

- (NSValue*)moxVisibleCharacterRange {
  // XXX this won't work with Textarea and such as we actually don't give
  // the visible character range.
  return [NSValue valueWithRange:NSMakeRange(0, [self textLength])];
}

- (BOOL)moxBlockSelector:(SEL)selector {
  if (selector == @selector(moxSetValue:) && [self isReadOnly]) {
    return YES;
  }

  return [super moxBlockSelector:selector];
}

- (void)moxSetValue:(id)value {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  nsString text;
  nsCocoaUtils::GetStringForNSString(value, text);
  if (mGeckoAccessible.IsAccessible()) {
    if (HyperTextAccessible* textAcc =
            mGeckoAccessible.AsAccessible()->AsHyperText()) {
      textAcc->ReplaceText(text);
    }
  } else {
    mGeckoAccessible.AsProxy()->ReplaceText(text);
  }
}

- (void)moxSetSelectedText:(NSString*)selectedText {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  NSString* stringValue = ToNSString(selectedText);
  if (!stringValue) {
    return;
  }

  int32_t start = 0, end = 0;
  nsString text;
  if (mGeckoAccessible.IsAccessible()) {
    if (HyperTextAccessible* textAcc =
            mGeckoAccessible.AsAccessible()->AsHyperText()) {
      textAcc->SelectionBoundsAt(0, &start, &end);
      textAcc->DeleteText(start, end - start);
      nsCocoaUtils::GetStringForNSString(stringValue, text);
      textAcc->InsertText(text, start);
    }
  } else {
    ProxyAccessible* proxy = mGeckoAccessible.AsProxy();
    nsString data;
    proxy->SelectionBoundsAt(0, data, &start, &end);
    proxy->DeleteText(start, end - start);
    nsCocoaUtils::GetStringForNSString(stringValue, text);
    proxy->InsertText(text, start);
  }
}

- (void)moxSetSelectedTextRange:(NSValue*)selectedTextRange {
  GeckoTextMarkerRange markerRange =
      [self textMarkerRangeFromRange:selectedTextRange];

  markerRange.Select();
}

- (void)moxSetVisibleCharacterRange:(NSValue*)visibleCharacterRange {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  NSRange range;
  if (!ToNSRange(visibleCharacterRange, &range)) {
    return;
  }

  if (mGeckoAccessible.IsAccessible()) {
    if (HyperTextAccessible* textAcc =
            mGeckoAccessible.AsAccessible()->AsHyperText()) {
      textAcc->ScrollSubstringTo(range.location, range.location + range.length,
                                 nsIAccessibleScrollType::SCROLL_TYPE_TOP_EDGE);
    }
  } else {
    mGeckoAccessible.AsProxy()->ScrollSubstringTo(
        range.location, range.location + range.length,
        nsIAccessibleScrollType::SCROLL_TYPE_TOP_EDGE);
  }
}

- (NSString*)moxStringForRange:(NSValue*)range {
  GeckoTextMarkerRange markerRange = [self textMarkerRangeFromRange:range];

  if (!markerRange.IsValid()) {
    return nil;
  }

  return markerRange.Text();
}

- (NSAttributedString*)moxAttributedStringForRange:(NSValue*)range {
  return [[[NSAttributedString alloc]
      initWithString:[self moxStringForRange:range]] autorelease];
}

- (NSValue*)moxRangeForLine:(NSNumber*)line {
  // XXX: actually get the integer value for the line #
  return [NSValue valueWithRange:NSMakeRange(0, [self textLength])];
}

- (NSNumber*)moxLineForIndex:(NSNumber*)index {
  // XXX: actually return the line #
  return @0;
}

- (NSValue*)moxBoundsForRange:(NSValue*)range {
  GeckoTextMarkerRange markerRange = [self textMarkerRangeFromRange:range];

  if (!markerRange.IsValid()) {
    return nil;
  }

  return markerRange.Bounds();
}

#pragma mark - mozAccessible

enum AXTextEditType {
  AXTextEditTypeUnknown,
  AXTextEditTypeDelete,
  AXTextEditTypeInsert,
  AXTextEditTypeTyping,
  AXTextEditTypeDictation,
  AXTextEditTypeCut,
  AXTextEditTypePaste,
  AXTextEditTypeAttributesChange
};

enum AXTextStateChangeType {
  AXTextStateChangeTypeUnknown,
  AXTextStateChangeTypeEdit,
  AXTextStateChangeTypeSelectionMove,
  AXTextStateChangeTypeSelectionExtend
};

- (void)handleAccessibleTextChangeEvent:(NSString*)change
                               inserted:(BOOL)isInserted
                            inContainer:(const AccessibleOrProxy&)container
                                     at:(int32_t)start {
  GeckoTextMarker startMarker(container, start);
  NSDictionary* userInfo = @{
    @"AXTextChangeElement" : self,
    @"AXTextStateChangeType" : @(AXTextStateChangeTypeEdit),
    @"AXTextChangeValues" : @[ @{
      @"AXTextChangeValue" : (change ? change : @""),
      @"AXTextChangeValueStartMarker" : startMarker.CreateAXTextMarker(),
      @"AXTextEditType" : isInserted ? @(AXTextEditTypeTyping)
                                     : @(AXTextEditTypeDelete)
    } ]
  };

  mozAccessible* webArea = [self topWebArea];
  [webArea moxPostNotification:NSAccessibilityValueChangedNotification
                  withUserInfo:userInfo];
  [self moxPostNotification:NSAccessibilityValueChangedNotification
               withUserInfo:userInfo];

  [self moxPostNotification:NSAccessibilityValueChangedNotification];
}

- (void)handleAccessibleEvent:(uint32_t)eventType {
  switch (eventType) {
    default:
      [super handleAccessibleEvent:eventType];
      break;
  }
}

#pragma mark -

- (long)textLength {
  return [[self text] length];
}

- (BOOL)isReadOnly {
  return [self stateWithMask:states::EDITABLE] == 0;
}

- (NSString*)text {
  // A password text field returns an empty value
  if (mRole == roles::PASSWORD_TEXT) {
    return @"";
  }

  id<MOXTextMarkerSupport> delegate = [self moxTextMarkerDelegate];
  return [delegate
      moxStringForTextMarkerRange:[delegate
                                      moxTextMarkerRangeForUIElement:self]];
}

- (GeckoTextMarkerRange)selection {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  id<MOXTextMarkerSupport> delegate = [self moxTextMarkerDelegate];
  GeckoTextMarkerRange selection =
      [static_cast<MOXTextMarkerDelegate*>(delegate) selection];

  if (!selection.Crop(mGeckoAccessible)) {
    // The selection is not in this accessible. Return invalid range.
    return GeckoTextMarkerRange();
  }

  return selection;
}

- (GeckoTextMarkerRange)textMarkerRangeFromRange:(NSValue*)range {
  NSRange r = [range rangeValue];

  GeckoTextMarker startMarker =
      GeckoTextMarker::MarkerFromIndex(mGeckoAccessible, r.location);

  GeckoTextMarker endMarker =
      GeckoTextMarker::MarkerFromIndex(mGeckoAccessible, r.location + r.length);

  return GeckoTextMarkerRange(startMarker, endMarker);
}

@end

@implementation mozTextLeafAccessible

- (BOOL)moxBlockSelector:(SEL)selector {
  if (selector == @selector(moxChildren) || selector == @selector
                                                (moxTitleUIElement)) {
    return YES;
  }

  return [super moxBlockSelector:selector];
}

- (NSString*)moxValue {
  return [super moxTitle];
}

- (NSString*)moxTitle {
  return nil;
}

- (NSString*)moxLabel {
  return nil;
}

- (NSString*)moxStringForRange:(NSValue*)range {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  NSRange r = [range rangeValue];
  GeckoTextMarkerRange textMarkerRange(mGeckoAccessible);
  textMarkerRange.mStart.mOffset += r.location;
  textMarkerRange.mEnd.mOffset =
      textMarkerRange.mStart.mOffset + r.location + r.length;

  return textMarkerRange.Text();
}

- (NSAttributedString*)moxAttributedStringForRange:(NSValue*)range {
  return [[[NSAttributedString alloc]
      initWithString:[self moxStringForRange:range]] autorelease];
}

- (NSValue*)moxBoundsForRange:(NSValue*)range {
  MOZ_ASSERT(!mGeckoAccessible.IsNull());

  NSRange r = [range rangeValue];
  GeckoTextMarkerRange textMarkerRange(mGeckoAccessible);

  textMarkerRange.mStart.mOffset += r.location;
  textMarkerRange.mEnd.mOffset = textMarkerRange.mStart.mOffset + r.length;

  return textMarkerRange.Bounds();
}

@end
