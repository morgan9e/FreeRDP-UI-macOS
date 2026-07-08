#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

static BOOL menuzap_performKeyEquivalent(id self, SEL _cmd, NSEvent *event) {
    return NO;
}

__attribute__((constructor))
static void menuzap_init(void) {
    Class cls = objc_getClass("NSMenu");
    if (!cls) return;
    Method m = class_getInstanceMethod(cls, @selector(performKeyEquivalent:));
    if (m) method_setImplementation(m, (IMP)menuzap_performKeyEquivalent);
}
