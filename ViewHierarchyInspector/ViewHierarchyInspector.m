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
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#define INDENT  4

#if __has_feature(objc_arc)
    #define BRIDGE __bridge
#else
    #define BRIDGE
#endif

// Let the magic being!!!
static void initialize(void) __attribute__((constructor));
static void initialize(void){

    // This is faily early on the the process intialization so
    // neither an autorelease pool is available, not
    // NSApp is available.
    @autoreleasepool {
        NSString* likesFrames = [[[NSProcessInfo processInfo] environment] objectForKey:@"SHOW_FRAMES"];
        ViewHierarchyInspector* viewInsepector = [ViewHierarchyInspector sharedViewInspector];
        if (likesFrames) {
            viewInsepector.likesFrames = YES;
            NSLog(@"*** Request to show frames accepted.");
        }
        [[NSNotificationCenter defaultCenter] addObserver:viewInsepector
                                                 selector:@selector(applicationWillFinishLaunching:)
                                                     name:NSApplicationWillFinishLaunchingNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:viewInsepector
                                                 selector:@selector(applicationDidFinishLaunching:)
                                                     name:NSApplicationDidFinishLaunchingNotification
                                                   object:nil];
        NSLog(@"*** Successfully initialized ViewHierarchy Library!");
    }
}


@implementation ViewHierarchyInspector
static ViewHierarchyInspector* gViewInspector = nil;
@synthesize likesFrames;
@synthesize viewBorderColor = _viewBorderColor;
@synthesize textColor = _textColor;

-(CGColorRef) viewBorderColor{
    if (_viewBorderColor == NULL) {
        _viewBorderColor = CGColorCreateGenericRGB(1.0, 0, 0, 1.0);
    }
    return _viewBorderColor;
}

-(CGColorRef) textColor{
    if (_textColor == NULL) {
        _textColor = CGColorCreateGenericRGB(0.8, 0.0, 0.0, 1.0);
    }
    return _textColor;
}

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
                                                 name:NSWindowDidBecomeKeyNotification
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
    NSToolbar* toolBar = [win toolbar];
    if (self.likesFrames) {
        NSFileHandle* stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSArray* toolBarItems = [toolBar visibleItems];
        for (NSToolbarItem* item in toolBarItems) {
            [stdOut writeStringWithFormat:@"{\n\tToolbar Label      : %@\n", item.label];
            [stdOut writeStringWithFormat:   @"\tToolbar Image name : %@\n", [item.image name]];
            if (item.view) {
                [stdOut writeStringWithFormat:@"\tToolbar View      :\n"];
                [self traverseViewHierarchy:item.view currentTreeHeight:0];
            }
            [stdOut writeStringWithFormat:@"\n}"];
        }
    }

    for (int i = 0 ; i<MIN(gViewInspector->maxIndex, MAX_WINDOW_CACHE_SIZE); i++) {
        if (gViewInspector->windowsTraversed[i] == (BRIDGE void*)win) {
            NSLog(@"Window %p became main window again!", win);
            return;
        }
    }
    gViewInspector->windowsTraversed[maxIndex++%MAX_WINDOW_CACHE_SIZE]=win;
    [self traverseViewHierarchy:contentView currentTreeHeight:0];
    [[NSFileHandle fileHandleWithStandardOutput] writeStringWithFormat:@"\n--\n"];
}


-(NSString*) classHierarchyUptoCocoaClass:(Class) currentClass{
    NSString* result = @"";
    NSString* topLevel = [NSString stringWithFormat:@"%s", class_getName(currentClass)];
    
    if ([topLevel hasPrefix:@"NS"] || [topLevel hasPrefix:@"CA"]) {
        return @"";
    }
    
    while ((currentClass  = class_getSuperclass(currentClass)) != [NSObject class]) {
        NSString* className = [NSString stringWithFormat:@"%s", class_getName(currentClass)];
        if ([className hasPrefix:@"NS"] || [className hasPrefix:@"CA"]) {
            break;
        }
        result = [result stringByAppendingFormat:@"%@ <- ", className];
    }
    return [result stringByAppendingFormat:@"%s", class_getName(currentClass)];
}

-(void) adornWithFrames: (id) viewOrLayer{
    
    if ([viewOrLayer isKindOfClass:[CALayer class]]) {
        CALayer* thisLayer = viewOrLayer;
        if ([thisLayer superlayer] == NULL) {
            thisLayer.borderColor = self.viewBorderColor;
            thisLayer.borderWidth = 1.0f;
            [thisLayer setNeedsDisplay];
        }
        return;
    }
    
    NSView* currentView = viewOrLayer;
    /* this is a view now. */
    
    if ([currentView layer] == NULL) {
        // This is not 100% right thing to do, but I don't
        // want to get rid of the content.
        CALayer* newLayer = [CALayer layer];
        [currentView setLayer:newLayer];
        currentView.wantsLayer = YES;
    }
    
    if (currentView.frame.size.width > 200) {
        currentView.layer.borderColor = self.viewBorderColor;
        currentView.layer.borderWidth = 1.0f;
        currentView.layer.cornerRadius = 6.0f;
    }else {
        currentView.layer.borderColor = self.viewBorderColor;
        currentView.layer.borderWidth = 1.0f;
    }
    
    currentView.layer.layoutManager = [CAConstraintLayoutManager layoutManager];

    /* IF we are the top level vew, we print frame info. */
    if (([[currentView subviews] count]==0)&&
        (currentView.frame.size.width > 40.0) &&
        (currentView.frame.size.height > 16.0)) {
        CATextLayer* textLayer = [CATextLayer layer];
        textLayer.string = [NSString stringWithFormat:@"%s", class_getName([currentView class])];
        textLayer.fontSize = 14.0;
        textLayer.foregroundColor = self.textColor;
        textLayer.constraints = [NSArray arrayWithObjects:
                                 [CAConstraint constraintWithAttribute:kCAConstraintMidX
                                                            relativeTo:@"superlayer"
                                                             attribute:kCAConstraintMidX],
                                 [CAConstraint constraintWithAttribute:kCAConstraintMidY
                                                            relativeTo:@"superlayer"
                                                             attribute:kCAConstraintMidY],
                                 nil];
        [currentView.layer addSublayer:textLayer];
    }
    currentView.layer.needsDisplayOnBoundsChange = YES;
    [currentView.layer setNeedsDisplay];
}

-(void) traverseViewHierarchy: (id) viewOrLayer
            currentTreeHeight: (NSUInteger) height{
    @autoreleasepool {
        NSFileHandle* stdOut = [NSFileHandle fileHandleWithStandardOutput];
        NSUInteger indentation = height*INDENT;
        NSArray* subViews;
        
        Class currentClass = [viewOrLayer class];
        
        for (int i = 0; i<indentation; i++) {
            [stdOut writeStringWithFormat:@" "];
        }
        
        
        [stdOut writeStringWithFormat:@" %s <- %@ <%@>",
         object_getClassName(viewOrLayer),
         (void*)viewOrLayer,
         [self classHierarchyUptoCocoaClass:currentClass],
         NSStringFromRect([viewOrLayer frame])
         ];
        
        if ([viewOrLayer isKindOfClass:[NSControl class]]) {
            if ([viewOrLayer respondsToSelector:@selector(cells)]) {
                NSArray* cells = [viewOrLayer cells];
                NSUInteger count = [cells count];
                [stdOut writeStringWithFormat:@"(Cells: "];
                do{
                    count = count - 1;
                    NSCell* cell = [cells objectAtIndex:count];
                    Class targetClass = [cell target]?[[cell target] class]:[[(NSControl*)viewOrLayer target] class];
                    SEL action = [cell action]?[cell action]:[(NSControl*)viewOrLayer action];
                    
                    if (count>=1){
                        [stdOut writeStringWithFormat:@"%@ -> -[%s %@] | ",
                         [cell title],
                         object_getClassName(targetClass),
                         NSStringFromSelector(action), 
                         [cell backgroundStyle], 
                         [[cell image] name]];
                    }else{
                        [stdOut writeStringWithFormat:@"%@ -> -[%s %@]) ",
                         [cell title],
                         object_getClassName(targetClass),
                         NSStringFromSelector(action),
                         [cell backgroundStyle], 
                         [[cell image] name]];
                    }
                }while (count > 0);
            }else{
                NSCell* controlCell = [viewOrLayer cell];
                Class targetClass = [controlCell target]?[[controlCell target] class]:[[(NSControl*)viewOrLayer target] class];
                SEL action = [controlCell action]?[controlCell action]:[(NSControl*)viewOrLayer action];
                
                if (controlCell) {
                    [stdOut writeStringWithFormat:@" (Cell : %@ -> -[%s %@]]) ",
                     [controlCell title],
                     object_getClassName(targetClass),
                     NSStringFromSelector(action),
                     [controlCell backgroundStyle], 
                     [[controlCell image] name]];
                }
            }
         }

        [stdOut writeStringWithFormat:@"\n"];
        
        if (self.likesFrames) {
            [self adornWithFrames:viewOrLayer];
        }
        
        if ([viewOrLayer isKindOfClass:[NSView class]]) {
            subViews = [viewOrLayer subviews];
            if ([viewOrLayer wantsLayer] && [viewOrLayer layer]) {
                [self traverseViewHierarchy:[viewOrLayer layer]
                          currentTreeHeight:(height+2)];
            }
        }else if([viewOrLayer isKindOfClass:[CALayer class]]){
            subViews = [viewOrLayer sublayers];
        }
        
        for (id subview in subViews) {
            [self traverseViewHierarchy:subview currentTreeHeight:(height+1)];
        }
    }
}


@end
