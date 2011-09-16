#import "CommandLineInstaller.h"

@implementation CommandLineInstaller
- (IBAction)installTool:(id)sender 
{
	[self executeScriptWithPrivileges: [[NSBundle mainBundle] pathForResource: @"InstallCommandLineTool.sh" ofType: NULL]];
}

- (IBAction)uninstallTool:(id)sender 
{
	[self executeScriptWithPrivileges: [[NSBundle mainBundle] pathForResource: @"UninstallCommandLineTool.sh" ofType: NULL]];
}

/*****************************************
 - Run script with privileges using Authentication Manager
*****************************************/
- (void)executeScriptWithPrivileges: (NSString *)pathToScript
{
	OSErr					err = noErr;
	AuthorizationRef 		authorizationRef;
	char					*args[2];
	char					resDirPath[4096];
	char					scriptPath[4096];

	//get path to script in c string format
	[pathToScript getCString: (char *)&scriptPath maxLength: 4096];
	
	//create array of arguments - first argument is the Resource directory of the Platypus application
	[[[NSBundle mainBundle] resourcePath] getCString: (char *)&resDirPath];
	args[0] = resDirPath;
	args[1] = NULL;
    
    // Use Apple's Authentication Manager APIs to get an Authorization Reference
    err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (err != errAuthorizationSuccess)
	{
		NSLog(@"Authorization for script execution failed - Error %d", err);
        return;
	}
	
	//use Authorization Reference to execute the script with privileges
    if (!(err = AuthorizationExecuteWithPrivileges(authorizationRef,(char *)&scriptPath, kAuthorizationFlagDefaults, args, NULL)) != noErr)
	{
		// wait for task to finish
		int child;
		wait(&child);
			
		// destroy the auth ref
		AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults);
	}
}

@end
