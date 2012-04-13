//
//  ViewHierarchyInspector.m
//  ViewHierarchyInspector
//

/**
 * Copyright (C) 2012 Yogesh Prem Swami. http://www.axelexic.org
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 * http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "ViewHierarchyInspector.h"
#import "NSFileHandle+StringIO.h"
#import <objc/runtime.h>
#define INDENT  4

// Let the magic being!!!
static void initialize(void) __attribute__((constructor));
static void initialize(void){
    @autoreleasepool {
        ViewHierarchyInspector* viewInsepector = [ViewHierarchyInspector sharedViewInspector];
        [[NSNotificationCenter defaultCenter] addObserver:viewInsepector
                                                 selector:@selector(applicationWillFinishLaunching:)
                                                     name:NSApplicationWillFinishLaunchingNotification
                                                   object:NSApp];
        [[NSNotificationCenter defaultCenter] addObserver:viewInsepector
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:NSApp];
        NSLog(@"*** Successfully initialized ViewHierarchy Library!");
    }
}


@implementation ViewHierarchyInspector
static ViewHierarchyInspector* gViewInspector = nil;

+(id) sharedViewInspector{
    return (gViewInspector)?gViewInspector:[[self alloc] init];
}

-(id) init{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        gViewInspector = [super init];
        assert(gViewInspector);
        gViewInspector->maxIndex = 0;
    });
    
    if (self != gViewInspector) {
        self = nil; // release memory that alloc created.
    }
    return gViewInspector;
}

#if !__has_feature(objc_arc)
-(oneway void) release{
    return;
}
#endif

-(void) applicationWillFinishLaunching:(__unused NSNotification *)aNotification{
    // Everytime a window becomes Main window, we will print it's
    // view hierarchy
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(printVewHierarchyOfMainWindow:)
                                                 name:NSWindowDidBecomeMainNotification
                                               object:nil];
    NSLog(@"*** WillFinishLaunching notification received!");
}

-(void) applicationDidFinishLaunching:(NSNotification *)aNotification{
    NSLog(@"*** DidFinishLaunching notification received!");
}

-(void) printVewHierarchyOfMainWindow: (NSNotification*) aNotification{
    NSWindow* win = [aNotification object];
    NSView* contentView = win.contentView;
    NSLog(@"Traversing window: %p <%@>", win, [win title]);
    
    for (int i = 0 ; i<gViewInspector->maxIndex; i++) {
        if (gViewInspector->windowsTraversed[i] == (__bridge void*)win) {
            NSLog(@"Window %p became main window again!", win);
            return;
        }
    }
    
    [self traverseViewHierarchy:contentView currentTreeHeight:0];
    [[NSFileHandle fileHandleWithStandardOutput] writeStringWithFormat:@"\n--\n"];
}


-(NSString*) classHierarchyUptoCocoaClass:(Class) currentClass{
    NSString* result = @"";
    NSString* topLevel = [NSString stringWithFormat:@"%s", class_getName(currentClass)];
    
    if ([topLevel hasPrefix:@"NS"]) {
        return @"";
    }
    
    while ((currentClass  = class_getSuperclass(currentClass)) != [NSObject class]) {
        NSString* className = [NSString stringWithFormat:@"%s", class_getName(currentClass)];
        if ([className hasPrefix:@"NS"]) {
            break;
        }
        result = [result stringByAppendingFormat:@"%@ <- ", className];
    }
    return [result stringByAppendingFormat:@"%s", class_getName(currentClass)];
}

-(void) traverseViewHierarchy: (NSView*) currentView currentTreeHeight: (NSUInteger) height{
    @autoreleasepool {
        NSFileHandle* stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSUInteger indentation = height*INDENT;
        NSArray* subViews = [currentView subviews];
        Class currentClass = [currentView class];
        
        for (int i = 0; i<indentation; i++) {
            [stdOut writeStringWithFormat:@" "];
        }
        
        [stdOut writeStringWithFormat:@" %s <- %@ <%@>\n",
         object_getClassName(currentView),
         [self classHierarchyUptoCocoaClass:currentClass],
         NSStringFromRect(currentView.frame)
         ];
                
        for (NSView* subview in subViews) {
            [self traverseViewHierarchy:subview currentTreeHeight:(height+1)];
            if ([subview isKindOfClass:[NSScrollView class]]) {
                NSScrollView* scrollView = (NSScrollView*)subview;
                [stdOut writeStringWithFormat:@"+"];
                [self traverseViewHierarchy:[scrollView documentView] currentTreeHeight:height+1];
            }
        }
    }
}

@end
