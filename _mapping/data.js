const architectureData = {
  "files": [
    {
      "name": "SwiftShelfApp.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/SwiftShelfApp.swift",
      "category": "App",
      "imports": ["SwiftUI", "Combine"],
      "types": ["SwiftShelfApp"],
      "dependencies": ["ViewModel.swift", "LibraryConfig.swift", "GlobalAudioManager.swift", "ContentView.swift"],
      "purpose": "Main app entry point, initializes global state objects"
    },
    {
      "name": "ContentView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/ContentView.swift",
      "category": "View",
      "imports": ["SwiftUI"],
      "types": ["ContentView", "SearchDisplayItem", "SearchResponse", "BookResult", "NarratorResult", "SeriesResult", "ItemDetailsFullScreenView", "ChapterSeekBar", "PlaybackSpeedControl", "PlayerControlButtonStyle", "ChapterButtonStyle"],
      "dependencies": ["ViewModel.swift", "LibraryConfig.swift", "GlobalAudioManager.swift", "LibrarySelectionView.swift", "LibraryDetailView.swift", "SettingsView.swift", "EPUBReaderView.swift", "LibraryItem.swift"],
      "purpose": "Main navigation hub with tab view, search, and now playing interface"
    },
    {
      "name": "ViewModel.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/ViewModel.swift",
      "category": "Manager",
      "imports": ["Foundation", "SwiftUI", "Combine"],
      "types": ["ViewModel", "APILogger", "LibrarySummary", "LibrariesWrapper", "LibraryResponse"],
      "dependencies": ["KeychainService.swift", "LibraryItem.swift"],
      "purpose": "Main API client and state management for server communication"
    },
    {
      "name": "GlobalAudioManager.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/GlobalAudioManager.swift",
      "category": "Manager",
      "imports": ["SwiftUI", "AVFoundation", "MediaPlayer", "Combine"],
      "types": ["GlobalAudioManager"],
      "dependencies": ["ViewModel.swift", "LibraryItem.swift", "MediaPlayerView.swift"],
      "purpose": "Global singleton for audio playback management and session handling"
    },
    {
      "name": "LibraryConfig.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/LibraryConfig.swift",
      "category": "Manager",
      "imports": ["Foundation", "Combine"],
      "types": ["LibraryConfig", "SelectedLibrary"],
      "dependencies": [],
      "purpose": "Manages selected libraries configuration with UserDefaults persistence"
    },
    {
      "name": "KeychainService.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/KeychainService.swift",
      "category": "Utility",
      "imports": ["Foundation", "Security"],
      "types": ["KeychainService", "KeychainError"],
      "dependencies": [],
      "purpose": "Secure credential storage in iOS Keychain"
    },
    {
      "name": "Logging.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/Logging.swift",
      "category": "Utility",
      "imports": ["Foundation"],
      "types": ["AppLogger"],
      "dependencies": [],
      "purpose": "File-based logging utility with async support"
    },
    {
      "name": "LibraryItem.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/LibraryItem.swift",
      "category": "Model",
      "imports": ["Foundation"],
      "types": ["LibraryItem", "Media", "Metadata", "AudioFile", "Chapter", "Track", "LibraryFile", "ResultsWrapper", "UserMediaProgress", "PlaybackSessionResponse", "PlaybackTrack"],
      "dependencies": [],
      "purpose": "Core data models for library items, audiobooks, and playback"
    },
    {
      "name": "LibrarySelectionView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/LibrarySelectionView.swift",
      "category": "View",
      "imports": ["SwiftUI"],
      "types": ["LibrarySelectionView"],
      "dependencies": ["ViewModel.swift", "LibraryConfig.swift", "LibraryDetailView.swift"],
      "purpose": "UI for selecting which libraries to display"
    },
    {
      "name": "LibraryDetailView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/LibraryDetailView.swift",
      "category": "View",
      "imports": ["SwiftUI", "AVFoundation", "Combine"],
      "types": ["LibraryDetailView", "LibraryItemDetailPopup", "LibraryCarouselView", "CarouselItemView", "ItemDetailsOverlay"],
      "dependencies": ["ViewModel.swift", "LibraryConfig.swift", "GlobalAudioManager.swift", "LibraryItem.swift", "CoverArtView.swift", "SettingsView.swift"],
      "purpose": "Displays library items in carousels with Recent and Continue sections"
    },
    {
      "name": "MediaPlayerView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/MediaPlayerView.swift",
      "category": "View",
      "imports": ["SwiftUI", "AVFoundation", "AVKit", "MediaPlayer", "Combine", "Foundation"],
      "types": ["MediaPlayerView", "PlayerViewModel", "NowPlayingBanner", "GlobalPlayerView", "BubbledButtonStyle", "FocusBindingModifier"],
      "dependencies": ["ViewModel.swift", "GlobalAudioManager.swift", "LibraryItem.swift", "Logging.swift"],
      "purpose": "Audio player UI with controls and playback management"
    },
    {
      "name": "CompactPlayerView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/CompactPlayerView.swift",
      "category": "View",
      "imports": ["SwiftUI", "Combine"],
      "types": ["CompactPlayerView"],
      "dependencies": ["GlobalAudioManager.swift", "ViewModel.swift"],
      "purpose": "Compact mini-player overlay showing current playback"
    },
    {
      "name": "CoverArtView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/CoverArtView.swift",
      "category": "View",
      "imports": ["SwiftUI"],
      "types": ["CoverArtView"],
      "dependencies": [],
      "purpose": "Reusable component for displaying cover art with aspect ratio handling"
    },
    {
      "name": "SettingsView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/SettingsView.swift",
      "category": "View",
      "imports": ["SwiftUI", "Combine"],
      "types": ["SettingsView", "ProgressBarColor", "RainbowProgressBar", "RainbowPreview"],
      "dependencies": ["ViewModel.swift", "LibraryConfig.swift", "LoginSheetView.swift"],
      "purpose": "App settings including library limits, appearance, playback speed"
    },
    {
      "name": "LoginSheetView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/LoginSheetView.swift",
      "category": "View",
      "imports": ["SwiftUI"],
      "types": ["LoginSheetView"],
      "dependencies": ["ViewModel.swift"],
      "purpose": "Login form for host and API key input"
    },
    {
      "name": "EPUBReaderView.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/EPUBReaderView.swift",
      "category": "View",
      "imports": ["SwiftUI"],
      "types": ["EPUBReaderView", "ChapterRow"],
      "dependencies": ["ViewModel.swift", "LibraryItem.swift", "EPUBParser.swift", "HTMLParser.swift", "GlobalAudioManager.swift"],
      "purpose": "Two-panel ebook reader with audio sync capability"
    },
    {
      "name": "EPUBParser.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/EPUBParser.swift",
      "category": "Utility",
      "imports": ["Foundation", "Compression"],
      "types": ["EPUBParser", "EPUBContent", "Chapter", "SpineItem", "TOCChapter"],
      "dependencies": [],
      "purpose": "EPUB file parsing with ZIP decompression and TOC extraction"
    },
    {
      "name": "HTMLParser.swift",
      "path": "/Users/michaeldvinci/code/swiftshelf-tvos/SwiftShelf/HTMLParser.swift",
      "category": "Utility",
      "imports": ["Foundation"],
      "types": ["HTMLParser"],
      "dependencies": [],
      "purpose": "Converts HTML to plain text for ebook display"
    }
  ],
  "relationships": [
    {"from": "SwiftShelfApp.swift", "to": "ViewModel.swift", "type": "instantiates"},
    {"from": "SwiftShelfApp.swift", "to": "LibraryConfig.swift", "type": "instantiates"},
    {"from": "SwiftShelfApp.swift", "to": "GlobalAudioManager.swift", "type": "uses"},
    {"from": "SwiftShelfApp.swift", "to": "ContentView.swift", "type": "displays"},
    {"from": "ContentView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "ContentView.swift", "to": "LibraryConfig.swift", "type": "observes"},
    {"from": "ContentView.swift", "to": "GlobalAudioManager.swift", "type": "observes"},
    {"from": "ContentView.swift", "to": "LibrarySelectionView.swift", "type": "displays"},
    {"from": "ContentView.swift", "to": "LibraryDetailView.swift", "type": "displays"},
    {"from": "ContentView.swift", "to": "SettingsView.swift", "type": "displays"},
    {"from": "ContentView.swift", "to": "EPUBReaderView.swift", "type": "displays"},
    {"from": "ContentView.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "ViewModel.swift", "to": "KeychainService.swift", "type": "uses"},
    {"from": "ViewModel.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "GlobalAudioManager.swift", "to": "ViewModel.swift", "type": "uses"},
    {"from": "GlobalAudioManager.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "GlobalAudioManager.swift", "to": "MediaPlayerView.swift", "type": "uses"},
    {"from": "LibraryDetailView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "LibraryDetailView.swift", "to": "LibraryConfig.swift", "type": "observes"},
    {"from": "LibraryDetailView.swift", "to": "GlobalAudioManager.swift", "type": "observes"},
    {"from": "LibraryDetailView.swift", "to": "CoverArtView.swift", "type": "uses"},
    {"from": "LibraryDetailView.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "LibraryDetailView.swift", "to": "SettingsView.swift", "type": "uses"},
    {"from": "LibrarySelectionView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "LibrarySelectionView.swift", "to": "LibraryConfig.swift", "type": "observes"},
    {"from": "LibrarySelectionView.swift", "to": "LibraryDetailView.swift", "type": "displays"},
    {"from": "MediaPlayerView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "MediaPlayerView.swift", "to": "GlobalAudioManager.swift", "type": "observes"},
    {"from": "MediaPlayerView.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "MediaPlayerView.swift", "to": "Logging.swift", "type": "uses"},
    {"from": "CompactPlayerView.swift", "to": "GlobalAudioManager.swift", "type": "observes"},
    {"from": "CompactPlayerView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "SettingsView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "SettingsView.swift", "to": "LibraryConfig.swift", "type": "observes"},
    {"from": "SettingsView.swift", "to": "LoginSheetView.swift", "type": "displays"},
    {"from": "LoginSheetView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "EPUBReaderView.swift", "to": "ViewModel.swift", "type": "observes"},
    {"from": "EPUBReaderView.swift", "to": "LibraryItem.swift", "type": "uses"},
    {"from": "EPUBReaderView.swift", "to": "EPUBParser.swift", "type": "uses"},
    {"from": "EPUBReaderView.swift", "to": "HTMLParser.swift", "type": "uses"},
    {"from": "EPUBReaderView.swift", "to": "GlobalAudioManager.swift", "type": "observes"}
  ],
  "architecture": {
    "app": [
      "SwiftShelfApp.swift"
    ],
    "views": [
      "ContentView.swift",
      "LibrarySelectionView.swift",
      "LibraryDetailView.swift",
      "MediaPlayerView.swift",
      "CompactPlayerView.swift",
      "CoverArtView.swift",
      "SettingsView.swift",
      "LoginSheetView.swift",
      "EPUBReaderView.swift"
    ],
    "managers": [
      "ViewModel.swift",
      "GlobalAudioManager.swift",
      "LibraryConfig.swift"
    ],
    "models": [
      "LibraryItem.swift"
    ],
    "utilities": [
      "KeychainService.swift",
      "Logging.swift",
      "EPUBParser.swift",
      "HTMLParser.swift"
    ]
  },
  "dataFlow": {
    "authentication": {
      "flow": "LoginSheetView → ViewModel → KeychainService",
      "description": "User credentials stored securely in iOS Keychain"
    },
    "libraryData": {
      "flow": "ViewModel → API → LibraryItem → ContentView/LibraryDetailView",
      "description": "Fetches libraries and items from Audiobookshelf API"
    },
    "audioPlayback": {
      "flow": "LibraryDetailView → GlobalAudioManager → PlayerViewModel → AVPlayer",
      "description": "Audio playback with session management and progress tracking"
    },
    "progressSync": {
      "flow": "GlobalAudioManager → ViewModel → API (session sync + progress PATCH)",
      "description": "Dual-layer progress tracking: ephemeral sessions + durable progress"
    },
    "ebookReading": {
      "flow": "ContentView → EPUBReaderView → EPUBParser → HTMLParser",
      "description": "EPUB parsing, pagination, and audio sync for ebooks"
    },
    "coverArt": {
      "flow": "ViewModel → API → UIImage → SwiftUI Image → CoverArtView",
      "description": "Cover art fetching with in-memory caching"
    },
    "configuration": {
      "flow": "SettingsView → LibraryConfig/ViewModel → UserDefaults/Keychain",
      "description": "App settings persisted locally"
    }
  },
  "keyFeatures": [
    "tvOS audiobook player with Audiobookshelf server integration",
    "Multi-library support with custom selection",
    "Global audio manager with background playback",
    "Dual-layer progress tracking (sessions + durable storage)",
    "EPUB reader with audio synchronization",
    "Cover art display with aspect ratio preservation",
    "Customizable progress bar colors including rainbow gradient",
    "Variable playback speed (0.5x - 3.0x)",
    "Chapter navigation and seeking",
    "Sleep timer functionality",
    "Now Playing interface with large artwork",
    "Search across books, narrators, and series",
    "Secure credential storage via iOS Keychain",
    "Remote playback controls via MPRemoteCommandCenter"
  ]
};
