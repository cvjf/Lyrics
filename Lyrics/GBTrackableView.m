//
//  GBTrackableView.m
//  Lyrics
//
//  Created by Andrew A.A. on 12/30/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import "GBTrackableView.h"

@implementation GBTrackableView

- (void)awakeFromNib
{
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self frame] options:NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingAssumeInside owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	if (![NSApp isActive])
		[self.delegate mouseEnteredTrackableView:theEvent];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if (![NSApp isActive])
		[self.delegate mouseExitedTrackableView:theEvent];
}

@end
