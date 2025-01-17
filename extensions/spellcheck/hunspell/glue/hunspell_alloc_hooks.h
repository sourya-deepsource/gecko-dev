/******* BEGIN LICENSE BLOCK *******
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Initial Developers of the Original Code is Mozilla Foundation.
 * Portions created by the Initial Developers
 * are Copyright (C) 2011 the Initial Developers. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 ******* END LICENSE BLOCK *******/

#ifndef alloc_hooks_h__
#define alloc_hooks_h__

/**
 * This file is force-included in hunspell code.  Its purpose is to add memory
 * reporting to hunspell without modifying its code, in order to ease future
 * upgrades.
 *
 * Currently, the memory allocated using operator new/new[] is not being
 * tracked, but that's OK, since almost all of the memory used by Hunspell is
 * allocated using C memory allocation functions.
 */

// XXX(Bug 1677529) Without undefining MALLOC_H, an ASAN build breaks. Maybe
// this is actually the right thing to do, but Bug 1677529 should check that.
#if defined(MALLOC_H) && !defined(XP_DARWIN)
#  undef MALLOC_H
#endif

#include "mozilla/mozalloc.h"
#include "mozHunspellAllocator.h"

#define malloc(size) HunspellAllocator::CountingMalloc(size)
#define calloc(count, size) HunspellAllocator::CountingCalloc(count, size)
#define free(ptr) HunspellAllocator::CountingFree(ptr)
#define realloc(ptr, size) HunspellAllocator::CountingRealloc(ptr, size)

#endif
