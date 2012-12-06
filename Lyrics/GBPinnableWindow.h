//
//  GBPinnableWindow.h
//  Lyrics
//
//  Created by Andrew A.A. on 8/20/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GBPinnableWindowFrameView;

@interface GBPinnableWindow : NSWindow

@property (nonatomic, strong) NSView *childContentView;

@end
