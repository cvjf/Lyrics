//
//  GBLyricsBrowserView.h
//  Lyrics
//
//  Created by 竞纬 戴 on 5/6/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol GBTrackbleViewDelegate;

@interface GBAppController : NSWindowController <NSApplicationDelegate, NSPopoverDelegate, NSSharingServiceDelegate, GBTrackbleViewDelegate>


@end
