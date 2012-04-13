//
//  ViewHierarchyInspector.h
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


#import <Foundation/Foundation.h>

@interface ViewHierarchyInspector : NSObject{
    @private
    void* windowsTraversed[512];    // It's a singleton, for Christ sake stop complaing...
    NSInteger maxIndex;
}

+(id) sharedViewInspector;
-(void) applicationWillFinishLaunching: (NSNotification*) aNotification;
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification;
-(void) traverseViewHierarchy: (NSView*) currentView currentTreeHeight: (NSUInteger) height;
-(void) printVewHierarchyOfMainWindow: (NSNotification*) aNotification;

@end
