//
//  GBPinnableWindow.m
//  Lyrics
//
//  Created by Andrew A.A. on 8/20/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import "GBPinnableWindow.h"
#import "GBPinnableWindowFrameView.h"


@implementation GBPinnableWindow

@synthesize childContentView = _childContentView;

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:bufferingType defer:flag];
	if (self)
	{
		[self setOpaque:NO];
		[self setBackgroundColor:[NSColor clearColor]];
	}
	return self;
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

- (NSRect)contentRectForFrameRect:(NSRect)windowFrame
{
    windowFrame.origin = NSZeroPoint;
    return NSInsetRect(windowFrame, WINDOW_FRAME_PADDING, WINDOW_FRAME_PADDING);
}

+ (NSRect)frameRectForContentRect:(NSRect)windowContentRect styleMask:(NSUInteger)windowStyle
{
    return NSInsetRect(windowContentRect, -WINDOW_FRAME_PADDING, -WINDOW_FRAME_PADDING);
}

- (void)setContentSize:(NSSize)aSize
{
	NSSize sizeDelta = aSize;
	NSSize childBoundsSize = [_childContentView bounds].size;
	sizeDelta.width -= childBoundsSize.width;
	sizeDelta.height -= childBoundsSize.height;

	GBPinnableWindowFrameView *frameView = [super contentView];
	NSSize newFrameSize = [frameView bounds].size;
	newFrameSize.width += sizeDelta.width;
	newFrameSize.height += sizeDelta.height;

	[super setContentSize:newFrameSize];
}

- (void)setContentView:(NSView *)aView
{
	if ([_childContentView isEqualTo:aView])
	{
		return;
	}

	NSRect bounds = [self frame];
	bounds.origin = NSZeroPoint;

	GBPinnableWindowFrameView *frameView = [super contentView];
	if (!frameView)
	{
		frameView = [[GBPinnableWindowFrameView alloc] initWithFrame:bounds];
		[super setContentView:frameView];
	}

	if (_childContentView)
	{
		[_childContentView removeFromSuperview];
	}
	_childContentView = aView;
	[_childContentView setFrame:[self contentRectForFrameRect:bounds]];
	[_childContentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[frameView addSubview:_childContentView];
}

- (id)contentView
{
	return _childContentView;
}


@end
