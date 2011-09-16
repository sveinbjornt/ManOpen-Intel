/* AproposDocument.h created by lindberg on Tue 10-Oct-2000 */

#import "SystemType.h"
#ifdef OPENSTEP
#import "NSDocument.h"
#else
#import <AppKit/NSDocument.h>
#endif

@class NSMutableArray;
@class NSTableColumn, NSTableView;

@interface AproposDocument : NSDocument
{
    NSString *title;
    NSMutableArray *titles;
    NSMutableArray *descriptions;

    IBOutlet NSTableView *tableView;
    IBOutlet NSTableColumn *titleColumn;
}

- (id)initWithString:(NSString *)apropos manPath:(NSString *)manPath title:(NSString *)title;
- (void)parseOutput:(NSString *)output;

- (IBAction)saveCurrentWindowSize:(id)sender;
- (IBAction)openManPages:(id)sender;

@end
