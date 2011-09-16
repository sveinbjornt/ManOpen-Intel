
#import <AppKit/AppKit.h>

#ifdef JAVA_OPENSTEP
#import <JavaVM/NSJavaVirtualMachine.h>
#endif

int main(int argc, const char *argv[]) {
#ifdef JAVA_OPENSTEP
    NSAutoreleasePool *pool;
    NSJavaVirtualMachine *vm;
    NSString *mbp, *zip, *cp;

    pool = [NSAutoreleasePool new];

    mbp = [[NSBundle mainBundle] bundlePath];
    zip = [NSString stringWithFormat:@"%@/Resources/Java/.zip", mbp];

    if ([[NSFileManager defaultManager] fileExistsAtPath:zip]) {
        cp = [NSString stringWithFormat:@"%@/Resources/Java/classes.zip:%@/Resources/Java:%@", mbp, mbp, [NSJavaVirtualMachine defaultClassPath]];
    } else {
        cp = [NSString stringWithFormat:@"%@/Resources/Java:%@/Resources/Java/classes.zip:%@", mbp, mbp, [NSJavaVirtualMachine defaultClassPath]];
    }

    vm = [[NSJavaVirtualMachine allocWithZone:NULL] initWithClassPath:cp];
    [vm findClass:@"com.apple.app.Application"];
#endif

    return NSApplicationMain(argc, argv);
}

