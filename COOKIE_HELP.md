# iCloud China Cookie Setup

1. Open `https://www.icloud.com.cn/settings/` and log in.
2. Press `F12`.
3. Open the `Network` tab.
4. Refresh the page.
5. Use the Network filter box to search `hme` or `maildomainws`.
6. Right-click a `maildomainws` or `hme` request if one appears.
7. Choose `Copy`, then `Copy as cURL`.
8. Paste the whole copied text into `cookies.txt`, save, and close Notepad.

Avoid `feedbackws/reportStats`; it usually misses the required
`X-APPLE-WEBAUTH-USER` cookie.

Raw cookie header strings still work too.

The launcher does not clear an existing `cookies.txt` automatically. When
replacing cookies, use `Ctrl+A` in Notepad, paste the new cURL text, then save.
The previous file is backed up as `cookies.txt.bak`.

## Auto Capture

Launcher path:

1. Choose `4. Manage iCloud cookie`.
2. Choose `3. Auto capture iCloud cookie`.
3. Log in in the opened browser window if needed.
4. The tool opens iCloud Plus, clicks Hide My Email, captures the app request,
   and writes `cookies.txt`.

This uses a separate `.cookie-browser-profile` browser profile.
