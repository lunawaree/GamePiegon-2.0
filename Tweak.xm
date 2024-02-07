#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>
#import <SpriteKit/SKView.h>
#import <UIKit/UIKit.h>

#import "Utils.h"
#import "Headers.h"

#define PLIST_PATH @"/var/mobile/Library/Preferences/com.donato.gameseagullprefs.plist"

BOOL boolForKey(NSString *key) {
    static NSUserDefaults *prefs;
    if (prefs == nil) {
        prefs = [[NSUserDefaults alloc] initWithSuiteName:PLIST_PATH];
    }
    NSNumber *value = [prefs objectForKey:key] ?: @YES;
    return [value boolValue];
}

int valueForKey(NSString *key) {
    static NSUserDefaults *prefs;
    if (prefs == nil) {
        prefs = [[NSUserDefaults alloc] initWithSuiteName:PLIST_PATH];
    }
    NSNumber *value = [prefs objectForKey:key] ?: @1;
    return [value intValue];
}

void HookMemory(Class class, SEL selector, uint64_t offset, uint32_t patch) {
    uint64_t *targetMethod = (uint64_t *)class_getInstanceMethod(class, selector);
    if (targetMethod) {
        targetMethod = (uint64_t *)((uint64_t)targetMethod + offset);
        if (mprotect((void *)((uintptr_t)targetMethod & ~(getpagesize() - 1)), getpagesize(), PROT_READ | PROT_WRITE) == 0) {
            *targetMethod = patch;
            msync(targetMethod, getpagesize(), MS_INVALIDATE | MS_SYNC);
            mprotect((void *)((uintptr_t)targetMethod & ~(getpagesize() - 1)), getpagesize(), PROT_READ | PROT_EXEC);
        }
    }
}

%hook ArcheryScene
-(void)setWind:(float)arg1 angle:(float)arg2 {
    if(boolForKey(@"archeryNoWind")) {
        %orig(0.0, 0.0);
    } else {
        %orig;
    }
}
%end

%hook PoolBall
-(BOOL)isStripes {
    if(boolForKey(@"showTrajectory")) {
        return true;
    }
    return %orig;
}
-(BOOL)isSolid {
    if(boolForKey(@"showTrajectory")) {
        return true;
    }
    return %orig;
}
%end

%hook TanksWind
-(void)setWind:(float)arg1 {
    if(boolForKey(@"tankNoWind")) {
        return %orig(0.0);
    }
    return %orig;
}
%end

%hook DartsScene
-(void)showScore2:(int)arg1 full_score:(int)arg2 multi:(int)arg3 pos:(CGPoint)arg4 send_pos:(CGPoint)arg5 {
    int dartMode = valueForKey(@"dartMode");
    int num;
    if(dartMode == 1) {
        num = 101;
    } else if(dartMode == 2) {
        num = 201;
    } else if(dartMode == 3) {
        num = 301;
    }
    if(boolForKey(@"oneDart")) {
        return %orig(arg1, num, arg3, arg4, arg5);
    } else {
        %orig;
    }
}
%end

%hook GolfBall
-(BOOL)inside {
    if(boolForKey(@"holeInOne")) {
        return true;
    }
    return %orig;
}
-(BOOL)hole {
    if(boolForKey(@"holeInOne")) {
        return true;
    }
    return %orig;
}
%end

%ctor {
    if (extendLines) {
        uint32_t patch = 0x52a9cdc8;
        uint8_t needle[4] = { 0x08, 0x4e, 0xa8, 0x52 };
        for (NSString *class in @[@"PoolScene", @"PoolScene2", @"PoolScene3"]) {
            uint64_t method = (uint64_t)[NSClassFromString(class) instanceMethodForSelector:@selector(mMove)];
            uint64_t result = bh_memmem((const uint8_t*)method, 0x1000, needle, 4);

            HookMemory(NSClassFromString(class), @selector(mMove), (result - method), patch);
        }
    }
    
    %init;
}
