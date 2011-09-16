
#import <Foundation/Foundation.h>
#import <AppKit/NSWorkspace.h>
#import <libc.h>  // for getopt()
#import <ctype.h> // for isdigit()
#import "ManOpenProtocol.h"

/*
 * The FOUNDATION_STATIC_INLINE #define appeared in Rhapsody, so if it's
 * not there we're on OPENSTEP.
 */
#ifndef FOUNDATION_STATIC_INLINE
#define OPENSTEP_ONLY
#endif

NSString *MakeAbsolutePath(const char *filename)
{
    NSString *currFile = [NSString stringWithCString:filename];

    if (![currFile isAbsolutePath])
    {
        currFile = [[[NSFileManager defaultManager] currentDirectoryPath]
                     stringByAppendingPathComponent:currFile];
    }

    return currFile;
}

void usage(const char *progname)
{
#ifdef OPENSTEP_ONLY
    fprintf(stderr,"%s: [-bk] [-M path] [-f file] [section] [title ...]\n", progname);
#else
    fprintf(stderr,"%s: [-bk] [-M path] [-f file] [section] [name ...]\n", progname);
#endif
}

int main (int argc, char * const *argv)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString          *manPath = nil;
    NSString          *section = nil;
    NSMutableArray    *files = [NSMutableArray array];
    BOOL              aproposMode = NO;
    BOOL              forceToFront = YES;
    int               i;
    char              c;
    NSDistantObject <ManOpen>  *server;
    int               maxConnectTries;
    int               connectCount;

    while ((c = getopt(argc,argv,"hbm:M:f:kaCcw")) != EOF)
    {
        switch(c)
        {
            case 'm':
            case 'M':
                manPath = [NSString stringWithCString:optarg];
                break;
            case 'f':
                [files addObject:MakeAbsolutePath(optarg)];
                break;
            case 'b':
                forceToFront = NO;
                break;
            case 'k':
                aproposMode = YES;
                break;
            case 'a':
            case 'C':
            case 'c':
            case 'w':
                // MacOS X man(1) options; no-op here.
                break;
            case 'h':
            case '?':
            default:
                usage(argv[0]);
                [pool release];
                exit(0);
        }
    }

    if (optind >= argc && [files count] <= 0)
    {
        usage(argv[0]);
        [pool release];
        exit(0);
    }

    if (optind < argc && !aproposMode)
    {
        NSString *tmp = [NSString stringWithCString:argv[optind]];

        if (isdigit(argv[optind][0])          ||
#ifdef OPENSTEP_ONLY
            [tmp isEqualToString:@"public"]   ||
            [tmp isEqualToString:@"new"]      ||
            [tmp isEqualToString:@"old"]      ||
#else
            /* These are configurable in /etc/man.conf; these are just the default strings.  Hm, they are invalid as of Panther. */
            [tmp isEqualToString:@"system"]   ||
            [tmp isEqualToString:@"commands"] ||
            [tmp isEqualToString:@"syscalls"] ||
            [tmp isEqualToString:@"libc"]     ||
            [tmp isEqualToString:@"special"]  ||
            [tmp isEqualToString:@"files"]    ||
            [tmp isEqualToString:@"games"]    ||
            [tmp isEqualToString:@"miscellaneous"] ||
            [tmp isEqualToString:@"misc"]     ||
            [tmp isEqualToString:@"admin"]    ||
            [tmp isEqualToString:@"n"]        || // Tcl pages on >= Panther
#endif
            [tmp isEqualToString:@"local"])
        {
            section = tmp;
            optind++;
        }
    }

    if (optind >= argc)
    {
        if ([section length] > 0)
        {
#ifdef OPENSTEP_ONLY
            fprintf(stderr, "But what do you want from section %s?\n", [section cString]);
#else
            /* MacOS X assumes it's a man page name */
            section = nil;
            optind--;
#endif
        }

        if (optind >= argc && [files count] <= 0)
        {
            [pool release];
            exit(0);
        }
    }

    /* 
     * MacOS X Beta seems to take a little longer to start the app, so we try up
     * to three times with sleep()s in between to give it a chance. First check
     * to see if there's a version running though.  MacOS X 10.0 takes even longer,
     * so up it to 8 tries.
     */
    maxConnectTries = 8;
    connectCount = 0;

    do {
        /* Try to connect to a running version... */
        server = [NSConnection rootProxyForConnectionWithRegisteredName:@"ManOpenApp" host:nil];

        if (server == nil) {
            /* 
             * Let Workspace try to start the app, and wait until it's up. If
             * launchApplication returns NO, then Workspace doesn't know about
             * the app, so there's no reason to keep waiting, and we bail out.
             */
            if (connectCount == 0) {
                if (![[NSWorkspace sharedWorkspace] launchApplication:@"ManOpen"])
                    maxConnectTries = 0;
            }

            [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    } while (server == nil && connectCount++ < maxConnectTries);

    if (server == nil)
    {
        fprintf(stderr,"Could not open connection to ManOpen\n");
        [pool release];
        exit(1);
    }

    [server setProtocolForProxy:@protocol(ManOpen)];

    for (i=0; i<[files count]; i++)
    {
        [server openFile:[files objectAtIndex:i] forceToFront:forceToFront];
    }

    if (manPath == nil && getenv("MANPATH") != NULL)
        manPath = [NSString stringWithCString:getenv("MANPATH")];

    for (i = optind; i < argc; i++)
    {
        NSString *currFile = [NSString stringWithCString:argv[i]];
        if (aproposMode)
            [server openApropos:currFile manPath:manPath forceToFront:forceToFront];
        else
            [server openName:currFile section:section manPath:manPath forceToFront:forceToFront];
    }

    [pool release];
    exit(0);       // insure the process exit status is 0
    return 0;      // ...and make main fit the ANSI spec.
}
