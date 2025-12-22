#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_SIMULATOR
NSErrorDomain const MTLIOErrorDomain = @"MTLIOErrorDomain";
NSErrorDomain const MTLTensorDomain = @"MTLTensorDomain";
#endif
