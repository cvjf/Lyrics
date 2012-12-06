//
//  GBPinnableWindowFrameView.m
//  Lyrics
//
//  Created by Andrew A.A. on 8/20/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import "GBPinnableWindowFrameView.h"

@implementation GBPinnableWindowFrameView

- (NSRect)resizeRect
{
	const CGFloat resizeBoxSize = 16.0;
	const CGFloat contentViewPadding = 5.5;

	NSRect contentViewRect = [[self window] contentRectForFrameRect:[[self window] frame]];
	NSRect resizeRect = NSMakeRect(
								   NSMaxX(contentViewRect) + contentViewPadding,
								   NSMinY(contentViewRect) - resizeBoxSize - contentViewPadding,
								   resizeBoxSize,
								   resizeBoxSize);
	
	return resizeRect;
}

//- (void)mouseDown:(NSEvent *)event
//{
//	NSPoint pointInView = [self convertPoint:[event locationInWindow] fromView:nil];
//
//	BOOL resize = NO;
//	if (NSPointInRect(pointInView, [self resizeRect]))
//	{
//		resize = YES;
//	}
//
//	NSWindow *window = [self window];
//	NSPoint originalMouseLocation = [window convertBaseToScreen:[event locationInWindow]];
//	NSRect originalFrame = [window frame];
//
//    while (YES)
//	{
//			//
//			// Lock focus and take all the dragged and mouse up events until we
//			// receive a mouse up.
//			//
//        NSEvent *newEvent = [window
//							 nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
//
//        if ([newEvent type] == NSLeftMouseUp)
//		{
//			break;
//		}
//
//			//
//			// Work out how much the mouse has moved
//			//
//		NSPoint newMouseLocation = [window convertBaseToScreen:[newEvent locationInWindow]];
//		NSPoint delta = NSMakePoint(
//									newMouseLocation.x - originalMouseLocation.x,
//									newMouseLocation.y - originalMouseLocation.y);
//
//		NSRect newFrame = originalFrame;
//
//		if (!resize)
//		{
//				//
//				// Alter the frame for a drag
//				//
//			newFrame.origin.x += delta.x;
//			newFrame.origin.y += delta.y;
//		}
//		else
//		{
//				//
//				// Alter the frame for a resize
//				//
//			newFrame.size.width += delta.x;
//			newFrame.size.height -= delta.y;
//			newFrame.origin.y += delta.y;
//
//				//
//				// Constrain to the window's min and max size
//				//
//			NSRect newContentRect = [window contentRectForFrameRect:newFrame];
//			NSSize maxSize = [window maxSize];
//			NSSize minSize = [window minSize];
//			if (newContentRect.size.width > maxSize.width)
//			{
//				newFrame.size.width -= newContentRect.size.width - maxSize.width;
//			}
//			else if (newContentRect.size.width < minSize.width)
//			{
//				newFrame.size.width += minSize.width - newContentRect.size.width;
//			}
//			if (newContentRect.size.height > maxSize.height)
//			{
//				newFrame.size.height -= newContentRect.size.height - maxSize.height;
//				newFrame.origin.y += newContentRect.size.height - maxSize.height;
//			}
//			else if (newContentRect.size.height < minSize.height)
//			{
//				newFrame.size.height += minSize.height - newContentRect.size.height;
//				newFrame.origin.y -= minSize.height - newContentRect.size.height;
//			}
//		}
//
//		[window setFrame:newFrame display:YES animate:NO];
//	}
//}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
	NSRectFill(rect);

	NSBezierPath *circlePath = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:10 yRadius:10];

	NSGradient *__autoreleasing aGradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor whiteColor], (CGFloat)0.0, [NSColor lightGrayColor], (CGFloat)1.0, nil];
	[aGradient drawInBezierPath:circlePath angle:90];

	[[NSColor whiteColor] set];
	[circlePath stroke];

	NSRect resizeRect = [self resizeRect];
	NSBezierPath *resizePath = [NSBezierPath bezierPathWithRect:resizeRect];

	[[NSColor lightGrayColor] set];
	[resizePath fill];

	[[NSColor darkGrayColor] set];
	[resizePath stroke];

	[[NSColor blackColor] set];
	NSString *windowTitle = [[self window] title];
	NSRect titleRect = [self bounds];
	titleRect.origin.y = titleRect.size.height - (WINDOW_FRAME_PADDING - 7);
	titleRect.size.height = (WINDOW_FRAME_PADDING - 7);
	NSMutableParagraphStyle *__autoreleasing paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setAlignment:NSCenterTextAlignment];
	[windowTitle drawWithRect:titleRect options:0 attributes:[NSDictionary dictionaryWithObjectsAndKeys:paragraphStyle, NSParagraphStyleAttributeName, [NSFont systemFontOfSize:14], NSFontAttributeName, nil]];
}


@end
