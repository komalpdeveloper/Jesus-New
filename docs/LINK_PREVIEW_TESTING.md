# Link Preview Feature - Testing Guide

## Manual Testing Checklist

### Basic Functionality
- [ ] Send a message with a URL (e.g., "Check out https://flutter.dev")
- [ ] Verify the link preview card appears below the message text
- [ ] Verify the preview shows title, description, and thumbnail (if available)
- [ ] Tap the preview card and verify it opens in browser

### URL Detection
- [ ] Test with http:// URL
- [ ] Test with https:// URL
- [ ] Test with URL at start of message
- [ ] Test with URL in middle of message
- [ ] Test with URL at end of message
- [ ] Test with URL-only message (no other text)
- [ ] Test with multiple URLs (should preview first one)

### Preview Content
- [ ] Test with URL that has Open Graph metadata (e.g., news article)
- [ ] Test with URL that has thumbnail image
- [ ] Test with URL without metadata (should show basic preview)
- [ ] Test with invalid/broken URL (should handle gracefully)
- [ ] Test with URL that times out (should handle gracefully)

### UI/UX
- [ ] Verify preview card styling matches message bubble design
- [ ] Verify preview card is tappable
- [ ] Verify text overflow is handled properly (ellipsis)
- [ ] Verify images load with placeholder
- [ ] Verify broken images show fallback icon
- [ ] Test on different screen sizes
- [ ] Test in both sent (isMe=true) and received (isMe=false) messages

### Performance
- [ ] Send multiple messages with links quickly
- [ ] Verify app doesn't freeze while fetching previews
- [ ] Verify messages send immediately (preview fetches async)
- [ ] Scroll through chat with many link previews
- [ ] Verify images are cached properly

### Edge Cases
- [ ] Very long URL
- [ ] URL with special characters
- [ ] URL with query parameters
- [ ] URL with fragments (#section)
- [ ] Shortened URLs (bit.ly, etc.)
- [ ] URLs from different domains (YouTube, Twitter, GitHub, etc.)
- [ ] Message with link + image attachment
- [ ] Message with link + haptic pattern

### Error Handling
- [ ] No internet connection when sending link
- [ ] Network error while fetching preview
- [ ] Invalid URL format
- [ ] URL that returns 404
- [ ] URL that redirects
- [ ] URL that requires authentication

## Test URLs

### Good Test URLs (with rich metadata)
```
https://flutter.dev
https://github.com
https://www.youtube.com/watch?v=dQw4w9WgXcQ
https://www.bbc.com/news
https://medium.com
```

### Edge Case URLs
```
https://example.com/very/long/path/with/many/segments/and/parameters?param1=value1&param2=value2&param3=value3
http://localhost:3000
https://bit.ly/3example
```

## Expected Behavior

### Successful Preview
1. User types message with URL
2. User presses send
3. Message appears immediately with text
4. Preview card appears with:
   - Thumbnail image (if available)
   - Page title
   - Description snippet
   - Domain name with link icon
5. Tapping card opens URL in browser

### Failed Preview
1. User types message with URL
2. User presses send
3. Message appears immediately with text
4. Preview card appears with:
   - Generic link icon (no thumbnail)
   - URL as title
   - Domain name
5. Tapping card still opens URL in browser

## Debugging

### Check Console Logs
```
🔗 Detected URL: [url]
✅ Link preview fetched: [title]
✅ Message sent successfully
```

### Common Issues
- **Preview not showing**: Check if URL is valid and accessible
- **Image not loading**: Check image URL and network connection
- **App freezing**: Ensure preview fetch is async
- **Wrong preview**: Check URL metadata (Open Graph tags)

## Firestore Data Verification

Check message document in Firestore:
```json
{
  "text": "Check out this link",
  "linkPreview": {
    "url": "https://example.com",
    "title": "Example Domain",
    "description": "Example description",
    "imageUrl": "https://example.com/image.jpg"
  },
  "timestamp": "...",
  "senderId": "...",
  "status": "sent"
}
```
