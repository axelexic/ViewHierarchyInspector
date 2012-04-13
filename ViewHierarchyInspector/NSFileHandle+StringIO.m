#import "NSFileHandle+StringIO.h"
#import <stdarg.h>

@implementation NSFileHandle (StringIO)
-(void) writeStringWithFormat: (NSString*) format, ...{
	if(format){
		NSString* formattedString;
		NSData* actualData;
		va_list args;
		va_start(args, format);
		formattedString = [[NSString alloc]
						   initWithFormat:format
						   arguments:args];
		actualData = [formattedString
					  dataUsingEncoding:NSUTF8StringEncoding
					  allowLossyConversion:YES
					  ];
		[self writeData:actualData];
	}
}
@end
