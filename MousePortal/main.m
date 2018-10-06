#import <AppKit/NSScreen.h>
#include <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MousePortal : NSObject
@property NSTimer *timer;
-(id)init;
-(void)positionMouseInCenter:(NSTimer *)aTimer;
-(void)positionMouseInCenterAfterDelay;
@end

@implementation MousePortal
-(id)init {
  id newInstance = [super init];
  return newInstance;
}

MousePortal *mp;

bool cmdDown = false;
bool tabDown = false;

-(void)positionMouseInCenter:(NSTimer *)aTimer {
  NSInteger frontmostAppPID = [NSWorkspace sharedWorkspace].frontmostApplication.processIdentifier;
  NSArray* windows = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
  
  for (NSDictionary* window in windows) {
    NSInteger windowOwnerPID = [window[(id)kCGWindowOwnerPID] intValue];
    
    if (windowOwnerPID == frontmostAppPID) {
      
      CGRect bounds;
      CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[window objectForKey:(id)kCGWindowBounds], &bounds);
      
      CGPoint newPosition = {bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2};
      
      CGEventRef eventRef = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, newPosition, kCGMouseButtonCenter);
      
      CGEventSetType(eventRef, kCGEventMouseMoved);
      
      CGEventPost(kCGSessionEventTap, eventRef);
      
      CFRelease(eventRef);
      
      break;
    }
  }
}

-(void)positionMouseInCenterAfterDelay {
  if (_timer) {
    [_timer invalidate];
    _timer = nil;
  }
  
  _timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                            target:self
                                          selector:@selector(positionMouseInCenter:)
                                          userInfo:nil
                                           repeats:NO];
}
@end

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
  
  CGEventFlags flags = CGEventGetFlags(event);
  
  CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
  
  if (keycode == 48 && type == kCGEventKeyDown && cmdDown) {
    tabDown = true;
  } else if (keycode == 55 && (flags & kCGEventFlagMaskCommand) == kCGEventFlagMaskCommand) {
    cmdDown = true;
    tabDown = false;
  } else if (keycode == 55 && tabDown && cmdDown) {
    cmdDown = tabDown = false;
    
    [mp positionMouseInCenterAfterDelay];
  }
  
  return event;
}

int main() {
  @autoreleasepool {
    mp = [[MousePortal alloc] init];
    
    CGEventMask eventMask = ((1 << kCGEventKeyDown) | (1 << kCGEventKeyUp) | (1 << kCGEventFlagsChanged)) ;
    CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                              eventMask, eventCallback, NULL);
    
    if (!eventTap) {
      fprintf(stderr, "failed to create event tap, MousePortal might be not allowed to access you mac, please check accessibility settings \n");
      exit(1);
    }
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
    CFRunLoopRun();
  }
  
  return 0;
}
