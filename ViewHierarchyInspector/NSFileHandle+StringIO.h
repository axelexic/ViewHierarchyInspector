#import <Foundation/Foundation.h>

@interface NSFileHandle (StringIO)
-(void) writeStringWithFormat: (NSString*) format, ...;
@end
