/*
 * The FOUNDATION_STATIC_INLINE #define appeared in Rhapsody, so if it's
 * not there we're on OPENSTEP.
 */
#import <Foundation/NSObjCRuntime.h>
#ifndef FOUNDATION_STATIC_INLINE
#define OPENSTEP
#else
  /* Cocoa (MacOS X) removed a bunch of defines from NSDebug.h */
  #import <Foundation/NSDebug.h>
  #ifndef NSZoneMallocEvent
  #define MACOS_X
  #endif
#endif
