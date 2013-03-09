//
//  GBLyricsBrowserView.m
//  Lyrics
//
//  Created by 竞纬 戴 on 5/6/12.
//  Copyright (c) 2012 Hunan Institute of Science. All rights reserved.
//

#import "GBTrackableView.h"

#import "GBAppController.h"
#import "iTunes.h"
#import <ScriptingBridge/ScriptingBridge.h>
#import <ApplicationServices/ApplicationServices.h>

#define GBLocString(key) NSLocalizedString (key, nil)
#define GBConvertFontToText(font) [NSString stringWithFormat:@"%@ - %.0f", font.familyName, font.pointSize]

NSString *GBPrefWindowIsAtTop;
NSString *GBPrefWindowIsPinned;
NSString *GBPrefLyricsDisplayFont;
NSString *GBPrefWindowIsAttachedToOthers;
NSString *GBPrefWindowAlphaValue;

NSUserDefaults *userDefaults;

NSString *kSearchQueryPrefix;

@interface GBAppController ()

@property (unsafe_unretained) IBOutlet NSButton	*postOnWeiboButton;
@property (unsafe_unretained) IBOutlet NSButton *postOnTwitterButton;

@property (nonatomic, strong) NSSharingService *weiboSharingService;
@property (nonatomic, strong) NSSharingService *twitterSharingServer;

@property (unsafe_unretained) IBOutlet NSTextView  *lyricsBrowser;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackName;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackAlbum;
@property (unsafe_unretained) IBOutlet NSTextField *currentTrackArtist;

@property (unsafe_unretained) IBOutlet NSPopover *preferencePopover;
@property (unsafe_unretained) IBOutlet NSTextField *fontRepresentationTextField;

@property (nonatomic, assign) CGFloat windowAlphaValue;

@property (nonatomic, strong) iTunesFileTrack *currentTrack;
@property (nonatomic, strong, readonly) iTunesApplication *iTunesApp;
@property (nonatomic, strong, readonly) NSArray *currentTrackDescription;

@property (nonatomic, assign) BOOL hasUnsavedChanges;
@property (nonatomic, assign) BOOL isInteractingWithUser;

@property (nonatomic, assign) BOOL mainWindowIsAtTop;
@property (nonatomic, assign) BOOL mainWindowIsPinned;
@property (nonatomic, assign) BOOL mainWindowIsAttachedToOthers;

- (void)lyricsViewContentDidChange:(NSNotification *)notification;
- (void)iTunesPlayerStateDidChange:(NSNotification *)notification;

- (void)askUserToCommitChanges:(id)sender;					// auto-update property self.userHasMadeChangesToLyrics
- (void)iTunesPlayerDidChangeToNewTrack;
- (void)iTunesPlayerDidStopPlaying;

- (IBAction)searchForLyrics:(id)sender;
- (IBAction)togglePreferencePopover:(id)sender;

- (IBAction)postOnWeiboPressed:(id)sender;
- (IBAction)postOnTwitterPressed:(id)sender;

- (IBAction)toggleFontPanel:(id)sender;

@end

@implementation GBAppController

@synthesize iTunesApp = _iTunesApp;
@synthesize mainWindowIsAtTop = _mainWindowIsAtTop;
@synthesize mainWindowIsAttachedToOthers = _mainWindowIsAttachedToOthers;
@synthesize mainWindowIsPinned = _mainWindowIsPinned;

+ (void)initialize
{
	GBPrefWindowIsAtTop  = @"GBPrefWindowIsAtTop";
	GBPrefWindowIsPinned = @"GBPrefWindowIsPinned";
	GBPrefWindowIsAttachedToOthers = @"GBPrefWindowIsAttachedToOthers";
	GBPrefLyricsDisplayFont = @"GBPrefLyricsDisplayFont";
	GBPrefWindowAlphaValue = @"GBPrefWindowAlphaValue";

	kSearchQueryPrefix = @"www.google.com/search?q=";

	userDefaults = [NSUserDefaults standardUserDefaults];

	NSData *fontData = [NSKeyedArchiver archivedDataWithRootObject:[NSFont fontWithName:@"Optima-Italic" size:14]];
	NSDictionary *defaults = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithBool:YES], GBPrefWindowIsAttachedToOthers, fontData, GBPrefLyricsDisplayFont, [NSNumber numberWithFloat:0.5], GBPrefWindowAlphaValue, nil];

	[userDefaults registerDefaults:defaults];
}


#pragma mark
#pragma mark App Controller

- (IBAction)quitApp:(id)sender
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	[NSApp terminate:nil];
}

- (IBAction)hideApp:(id)sender
{
	[[self.window animator] setAlphaValue:0.0];
	NSTimer *hideTimer = [NSTimer timerWithTimeInterval:0 target:NSApp selector:@selector(hide:) userInfo:nil repeats:NO];
	[hideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
	[[NSRunLoop currentRunLoop] addTimer:hideTimer forMode:NSDefaultRunLoopMode];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[[self.window animator] setAlphaValue:1.0];
	NSTimer *unhideTimer = [NSTimer timerWithTimeInterval:0 target:NSApp selector:@selector(unhide:) userInfo:nil repeats:NO];
	[unhideTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
	[[NSRunLoop currentRunLoop] addTimer:unhideTimer forMode:NSDefaultRunLoopMode];

	return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(lyricsViewContentDidChange:) 
												 name:NSTextDidChangeNotification object:nil];
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self 
														selector:@selector(iTunesPlayerStateDidChange:)
															name:@"com.apple.iTunes.playerInfo" object:nil];

	NSData *displayFontData = [userDefaults objectForKey:GBPrefLyricsDisplayFont];
	NSFont *displayFont = [NSKeyedUnarchiver unarchiveObjectWithData:displayFontData];

	[self.fontRepresentationTextField setStringValue:GBConvertFontToText(displayFont)];

	[[NSFontManager sharedFontManager] setDelegate:self];

	[self.lyricsBrowser setAlignment:NSCenterTextAlignment];
	[self.lyricsBrowser setTextColor:[NSColor whiteColor]];
	[self.lyricsBrowser setFont:displayFont];
	[self.lyricsBrowser setInsertionPointColor:[NSColor whiteColor]];

	// update the lyrics browser accrodingly
	if (self.iTunesApp.isRunning && (self.iTunesApp.currentTrack.name != nil))
		[self iTunesPlayerDidChangeToNewTrack];
	else
		[self iTunesPlayerDidStopPlaying];

	[self.postOnWeiboButton sendActionOn:NSLeftMouseUpMask];
	[self.postOnTwitterButton sendActionOn:NSLeftMouseUpMask];

	[self willChangeValueForKey:@"windowAlphaValue"];
	_windowAlphaValue = [userDefaults floatForKey:GBPrefWindowAlphaValue];
	[self didChangeValueForKey:@"windowAlphaValue"];

	[(GBTrackableView *)self.window.contentView setDelegate:self];

	[self.window orderFront:self];
}

- (void)mouseEnteredTrackableView:(NSEvent *)event
{
	[[self.window animator] setAlphaValue:1];
}

- (void)mouseExitedTrackableView:(NSEvent *)event
{
	[[self.window animator] setAlphaValue:self.windowAlphaValue];
}

- (void)applicationWillBecomeActive:(NSNotification *)notification
{
	if (self.window.alphaValue != 1)
		[self.window.animator setAlphaValue:1];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
	[self.window.animator setAlphaValue:self.windowAlphaValue];
}

- (void)toggleFontPanel:(id)sender
{
	[[NSFontPanel sharedFontPanel] setIsVisible:YES];
}

- (void)changeFont:(NSFontManager *)sender
{
	NSFont *newFont = [sender convertFont:self.lyricsBrowser.font];
	[self.lyricsBrowser setFont:newFont];
	[self.fontRepresentationTextField setStringValue:GBConvertFontToText(newFont)];

	[userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:newFont] forKey:GBPrefLyricsDisplayFont];
}

- (void)setWindowAlphaValue:(CGFloat)windowAlphaValue
{
	if (_windowAlphaValue == 1)
		[self.window.contentView setDelegate:self];
	else if (windowAlphaValue == 1) {
		[self.window.contentView setDelegate:nil];
		[[self.window animator] setAlphaValue:1];
	}

	_windowAlphaValue = windowAlphaValue;

	[userDefaults setFloat:windowAlphaValue forKey:GBPrefWindowAlphaValue];
}


#pragma mark
#pragma mark iTunes Control

- (IBAction)commitChangesToLyrics:(id)sender
{
	[self askUserToCommitChanges:sender];
}

- (void)lyricsViewContentDidChange:(NSNotification *)notification
{
	if (!self.hasUnsavedChanges)
		self.hasUnsavedChanges = YES;
}

- (void)iTunesPlayerStateDidChange:(NSNotification *)notification
{
	if (self.isInteractingWithUser)
		return;

	NSString *playerState = [notification.userInfo valueForKey:@"Player State"];

	if ([playerState isEqualToString:@"Playing"])
	{
		if (![self.currentTrack.persistentID isEqualToString:self.iTunesApp.currentTrack.persistentID])
			[self iTunesPlayerDidChangeToNewTrack];
	}
	
	else if ([playerState isEqualToString:@"Stopped"])
		[self iTunesPlayerDidStopPlaying];
}

- (void)iTunesPlayerDidChangeToNewTrack
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	self.currentTrack = [self.iTunesApp.currentTrack get];
	self.hasUnsavedChanges = NO;		// takes care of window title
}

- (void)iTunesPlayerDidStopPlaying
{
	if (self.hasUnsavedChanges)
		[self askUserToCommitChanges:nil];

	self.currentTrack = nil;
	self.hasUnsavedChanges = NO;
}

- (void)askUserToCommitChanges:(id)sender
{
	if (!self.window.isVisible)
		[[self.window animator] setAlphaValue:1.0];
	
	self.isInteractingWithUser = YES;
	NSString *otherButtonTitle = ( sender == nil ? GBLocString(@"Discard") /* track changed */ : GBLocString(@"Cancel")	/* user clicked save */ );

	NSAlert *saveAlert = [NSAlert alertWithMessageText:GBLocString(@"SaveAlertMessage") defaultButton:GBLocString(@"Save") alternateButton:GBLocString(@"Export...") otherButton:otherButtonTitle informativeTextWithFormat:@"%@: %@\n%@: %@", GBLocString(@"Artist"), self.currentTrack.artist, GBLocString(@"Track"), self.currentTrack.name];
	
	[saveAlert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(saveLyricsSheetDidEnd:returnCode:contextInfo:) contextInfo:(void *)sender];
	[saveAlert runModal];			// very important!!!
}

- (void)saveLyricsSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(id)sender
{
	if (returnCode == NSAlertDefaultReturn) {
		self.currentTrack.lyrics = self.lyricsBrowser.string;
		self.hasUnsavedChanges = NO;
	}

	else if (returnCode == NSAlertOtherReturn)
	{
		if (!sender)
			self.hasUnsavedChanges = NO;
	}
	
	else if (returnCode == NSAlertAlternateReturn)
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		
		[savePanel setNameFieldStringValue:[NSString stringWithFormat:@"%@ - %@", self.currentTrack.artist, self.currentTrack.name]];
		[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"txt"]];
		NSInteger returnCode = [savePanel runModal];
		if (returnCode == NSFileHandlingPanelOKButton)
			[self.lyricsBrowser.string writeToURL:savePanel.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
		
		self.hasUnsavedChanges = NO;
	}

	self.isInteractingWithUser = NO;
	[NSApp stopModal];			// stops the modal session incurred by askUserToCommitChanges: sheet
}


#pragma mark
#pragma mark Properties

- (iTunesApplication *)iTunesApp
{
	if (!_iTunesApp)
		_iTunesApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
	return _iTunesApp;
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
	_hasUnsavedChanges = hasUnsavedChanges;
	
	if (self.currentTrack != nil)
	{
		if (_hasUnsavedChanges)
			self.window.title = [self.currentTrack.name stringByAppendingString:GBLocString(@"Edited")];
		else
		{
			self.window.title = self.currentTrack.name;
			[[self.lyricsBrowser undoManager] removeAllActionsWithTarget:self.lyricsBrowser.textStorage];		// important!!!!!!!!
		}
	}
	else
		self.window.title = GBLocString(@"Lyrics");
}

- (void)setCurrentTrack:(iTunesFileTrack *)currentTrack
{
	_currentTrack = currentTrack;
	
	if (_currentTrack)
	{
		self.lyricsBrowser.string				= _currentTrack.lyrics;
		self.currentTrackAlbum.stringValue		= _currentTrack.album;
		self.currentTrackArtist.stringValue		= _currentTrack.artist;
		self.currentTrackName.stringValue		= _currentTrack.name;
		
		[self.lyricsBrowser setEditable:YES];
		[self.lyricsBrowser scrollToBeginningOfDocument:self];
	}

	else
	{
		self.lyricsBrowser.string				= @"";
		self.currentTrackAlbum.stringValue		= @"";
		self.currentTrackArtist.stringValue		= @"";
		self.currentTrackName.stringValue		= @"";
		
		[self.lyricsBrowser setEditable:NO];
	}
}


#pragma mark
#pragma mark Popover View

- (BOOL)mainWindowIsAtTop
{
	_mainWindowIsAtTop = [userDefaults boolForKey:GBPrefWindowIsAtTop];

	if (_mainWindowIsAtTop)
		[self.window setLevel:NSFloatingWindowLevel];
	else
		[self.window setLevel:NSNormalWindowLevel];
	
	return _mainWindowIsAtTop;
}

- (void)setMainWindowIsAtTop:(BOOL)mainWindowIsAtTop
{
	if (_mainWindowIsAtTop == mainWindowIsAtTop)
		return;

	_mainWindowIsAtTop = mainWindowIsAtTop;

	if (_mainWindowIsAtTop)
		[self.window setLevel:NSFloatingWindowLevel];
	else
		[self.window setLevel:NSNormalWindowLevel];

	[userDefaults setBool:_mainWindowIsAtTop forKey:GBPrefWindowIsAtTop];

}

- (BOOL)mainWindowIsPinned
{
	_mainWindowIsPinned = [userDefaults boolForKey:GBPrefWindowIsPinned];

	if (_mainWindowIsPinned)
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	else
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

	return _mainWindowIsPinned;
}

- (void)setMainWindowIsPinned:(BOOL)mainWindowIsPinned
{
	if (mainWindowIsPinned == _mainWindowIsPinned)
		return;

	_mainWindowIsPinned = mainWindowIsPinned;

	if (_mainWindowIsPinned)
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorDefault];
	else
		[self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];

	[userDefaults setBool:_mainWindowIsPinned forKey:GBPrefWindowIsPinned];
}

- (BOOL)mainWindowIsAttachedToOthers
{
	_mainWindowIsAttachedToOthers = [userDefaults boolForKey:GBPrefWindowIsAttachedToOthers];

	if (!_mainWindowIsAttachedToOthers) {
		ProcessSerialNumber psn = { 0, kCurrentProcess };

		TransformProcessType(&psn, kProcessTransformToForegroundApplication);
		SetFrontProcess(&psn);
	}

	return _mainWindowIsAttachedToOthers;
}

- (void)setMainWindowIsAttachedToOthers:(BOOL)mainWindowIsAttachedToOthers
{
	_mainWindowIsAttachedToOthers = mainWindowIsAttachedToOthers;
	
	ProcessSerialNumber psn = { 0, kCurrentProcess };

	if (_mainWindowIsAttachedToOthers == NSOnState) {
		TransformProcessType(&psn, kProcessTransformToUIElementApplication);
		SetFrontProcess(&psn);
	}
	else {
        TransformProcessType(&psn, kProcessTransformToForegroundApplication);
        SetFrontProcess(&psn);
	}

	[userDefaults setBool:_mainWindowIsAttachedToOthers forKey:GBPrefWindowIsAttachedToOthers];
}

- (void)togglePreferencePopover:(NSButton *)sender
{
	if (self.preferencePopover.shown)
		[self.preferencePopover close];
	else
		[self.preferencePopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMaxYEdge];
}

- (void)searchForLyrics:(id)sender
{
	NSString *trackName = self.currentTrackName.stringValue;
	NSString *trackArtist = self.currentTrackArtist.stringValue;

	NSString *searchQueryRaw = [[NSString stringWithFormat:@"%@ %@", [trackArtist isEqualToString:@""] ? trackName : [NSString stringWithFormat:@"%@ %@", trackArtist, trackName], GBLocString(@"lyrics")] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSString *searchQuery = [searchQueryRaw stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	NSString *searchURL = [NSString stringWithFormat:@"http://%@%@", kSearchQueryPrefix, searchQuery];

//	NSLog(@"%@", [NSURL URLWithString:searchURL]);

	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:searchURL]];
}



#pragma mark
#pragma mark Sharing Services

- (void)postOnWeiboPressed:(id)sender
{
	NSSharingService *weiboService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnSinaWeibo];

	weiboService.delegate = self;

	[weiboService performWithItems:self.currentTrackDescription];
}

- (void)postOnTwitterPressed:(id)sender
{
	NSSharingService *twitterService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];

	twitterService.delegate = self;

	[twitterService performWithItems:self.currentTrackDescription];
}

- (NSWindow *)sharingService:(NSSharingService *)sharingService sourceWindowForShareItems:(NSArray *)items sharingContentScope:(NSSharingContentScope *)sharingContentScope
{
	return self.window;
}

- (NSSharingService *)weiboSharingService
{
	if (!_weiboSharingService) {
		_weiboSharingService = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnSinaWeibo];
		_weiboSharingService.delegate = self;
	}
	return _weiboSharingService;
}

- (NSSharingService *)twitterSharingServer
{
	if (!_twitterSharingServer) {
		_twitterSharingServer = [NSSharingService sharingServiceNamed:NSSharingServiceNamePostOnTwitter];
		_twitterSharingServer.delegate = self;
	}
	return _twitterSharingServer;
}

- (NSArray *)currentTrackDescription
{
	NSMutableString *descriptionStr = [[NSMutableString alloc] initWithCapacity:30];

	if (![self.currentTrackArtist.stringValue isEqualToString:@""])
		[descriptionStr appendFormat:@"#%@# by ", self.currentTrackName.stringValue];

	[descriptionStr appendFormat:@"#%@# ", self.currentTrackArtist.stringValue];

	iTunesArtwork *artwork = [[self.currentTrack.artworks get] lastObject];
	NSImage *artworkImage = nil;

	if (artwork)
		artworkImage = [[NSImage alloc] initWithData:artwork.rawData];

	return [NSArray arrayWithObjects:descriptionStr, artworkImage, nil];
}


@end
