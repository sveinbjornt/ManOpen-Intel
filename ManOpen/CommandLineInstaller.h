#import <Cocoa/Cocoa.h>

@interface CommandLineInstaller : NSObject 
{

}
- (IBAction)installTool:(id)sender;
- (IBAction)uninstallTool:(id)sender;
- (void)executeScriptWithPrivileges: (NSString *)pathToScript;
@end
