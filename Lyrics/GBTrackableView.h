//
//  GBTrackableView.h
//  Lyrics
//
//  Created by Andrew A.A. on 12/30/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol GBTrackbleViewDelegate;

@interface GBTrackableView : NSView

@property (nonatomic, strong) id<GBTrackbleViewDelegate> delegate;

@end

@protocol GBTrackbleViewDelegate <NSObject>

@required
- (void)mouseEnteredTrackableView:(NSEvent *)event;
- (void)mouseExitedTrackableView:(NSEvent *)event;

@end
