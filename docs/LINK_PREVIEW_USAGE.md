# Link Preview Feature - Usage Guide

## How It Works

When users send messages containing URLs, the app automatically:
1. Detects the URL in the message text
2. Fetches metadata (title, description, thumbnail) from the URL
3. Displays a rich preview card below the message
4. Allows tapping the card to open the link in a browser

## User Experience

### Sending a Link
1. Type or paste a URL in the message input field
2. The URL can be anywhere in the message text
3. Press send
4. The message appears with a preview card showing:
   - Thumbnail image (if available)
   - Page title
   - Description snippet
   - Domain name

### Opening a Link
- Tap anywhere on the preview card
- The link opens in the device's default browser
- Works with all standard http/https URLs

## Examples

### Message with Link
```
User types: "Check out this article https://example.com/article"

Display:
┌─────────────────────────────┐
│ Check out this article      │
│ https://example.com/article │
│                             │
│ ┌─────────────────────────┐ │
│ │   [Thumbnail Image]     │ │
│ │                         │ │
│ │ Article Title           │ │
│ │ Brief description...    │ │
│ │ 🔗 example.com          │ │
│ └─────────────────────────┘ │
│                             │
│ 12:34 ✓✓                    │
└─────────────────────────────┘
```

### Link-Only Message
```
User types: "https://youtube.com/watch?v=..."

Display:
┌─────────────────────────────┐
│ https://youtube.com/...     │
│                             │
│ ┌─────────────────────────┐ │
│ │   [Video Thumbnail]     │ │
│ │                         │ │
│ │ Video Title             │ │
│ │ Video description...    │ │
│ │ 🔗 youtube.com          │ │
│ └─────────────────────────┘ │
│                             │
│ 12:34 ✓✓                    │
└─────────────────────────────┘
```

## Supported URLs

- ✅ Standard websites (http/https)
- ✅ Social media links (Twitter, Facebook, etc.)
- ✅ Video platforms (YouTube, Vimeo, etc.)
- ✅ News articles
- ✅ Blog posts
- ✅ Any URL with Open Graph metadata

## Fallback Behavior

If metadata cannot be fetched:
- The preview card still displays
- Shows a generic link icon instead of thumbnail
- Displays the URL as the title
- Still tappable to open in browser

## Performance

- Link previews are cached for 24 hours
- Metadata fetching happens asynchronously
- Does not block message sending
- Optimized image loading with placeholders

## Privacy

- Link preview fetching is done client-side
- No data is stored on external servers
- Original URL is preserved in the message
- Users can still copy/share the raw URL

## Technical Notes

### URL Detection
- Automatically detects the first URL in message text
- Supports both http and https protocols
- Handles URLs with query parameters and fragments

### Metadata Sources
- Open Graph tags (og:title, og:description, og:image)
- Twitter Card metadata
- Standard HTML meta tags
- Fallback to page title and description

### Error Handling
- Gracefully handles network errors
- Falls back to basic URL display
- Does not prevent message sending
- Logs errors for debugging
