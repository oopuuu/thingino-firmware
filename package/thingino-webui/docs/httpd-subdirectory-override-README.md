# BusyBox httpd Subdirectory ACL Override Patch

This patch modifies BusyBox httpd to allow subdirectories to override parent directory password protection with completely open access (no Basic Auth challenge at all).

## Problem Solved

By default, BusyBox httpd requires authentication for all subdirectories if a parent directory requires it. Even worse, you can't selectively disable authentication for specific subdirectories - they would still prompt for Basic Auth.

This patch allows you to mark specific paths as **completely open** - no authentication challenge whatsoever, even if a parent path requires a password.

## Changes Made

1. **New `is_open_access()` function**: Checks if a path has an explicit "no auth required" rule
2. **Most Specific Path Matching**: Finds the longest matching path prefix to determine which rule applies
3. **Skip Auth Challenge**: Paths marked as open access skip the HTTP 401 challenge entirely

## Usage

### Configuration Format

In your httpd configuration file (typically `/etc/httpd.conf` or specified with `-c`):

```
# Protect root with password - requires Basic Auth
/:username:password

# Mark /onvif/ as completely open - NO Basic Auth at all (overrides parent)
/onvif:*:

# Alternative syntax - empty credentials also means open access
/public:
```

### Example Configuration

```bash
# Require authentication for everything under /
/:admin:$1$abcd1234$encryptedpasswordhash

# Completely open access to ONVIF endpoints - no auth challenge
/onvif:*:

# Open access to public assets - no auth challenge
/public:

# But /admin requires different credentials
/admin:superuser:$1$xyz$differenthash
```

### How It Works - Path Matching Priority

The most specific (longest) path match wins:

1. Request to `/` → matches `/:admin:pass` → requires auth
2. Request to `/index.html` → matches `/:admin:pass` → requires auth  
3. Request to `/onvif/` → matches `/onvif:*:` (longer/more specific) → **NO AUTH**
4. Request to `/onvif/device_service` → matches `/onvif:*:` → **NO AUTH**
5. Request to `/public/logo.png` → matches `/public:` → **NO AUTH**
6. Request to `/admin/` → matches `/admin:superuser:pass` → requires auth

### Applying the Patch

```bash
cd ~/dl/busybox/busybox-1.37.0
patch -p0 < ~/httpd-subdirectory-override.patch

# Configure and build
make menuconfig  # Enable HTTPD and HTTPD_AUTH_MD5 features
make
```

### Testing

```bash
# Start httpd with your config
./busybox httpd -f -p 8080 -c /etc/httpd.conf

# Test protected root (should get 401 Unauthorized)
curl -v http://localhost:8080/
# Expected: HTTP/1.1 401 Unauthorized + WWW-Authenticate header

# Test open subdirectory (should get 200 OK with NO auth challenge)
curl -v http://localhost:8080/onvif/
# Expected: HTTP/1.1 200 OK (or 404) with NO WWW-Authenticate header
```

## Technical Details

The patch modifies two areas in `networking/httpd.c`:

1. **New `is_open_access()` function** (before `check_user_passwd()`):
   - Searches all authentication rules for the most specific path match
   - Returns 1 if the matched rule has empty credentials (`""`) or `"*:"`
   - Returns 0 otherwise

2. **Modified auth check** (in `handle_incoming_and_exit()`):
   - Before checking credentials, first calls `is_open_access()`
   - If true, sets `authorized = 1` and skips all authentication
   - No HTTP 401 response is sent, no WWW-Authenticate header

## Open Access Markers

Two syntaxes mark a path as requiring no authentication:

1. `*:` - Explicit "any user, empty password"
2. Empty string after colon - e.g., `/path:`

Both mean: **completely skip authentication for this path**.

## Patch Location

- Patch file: `~/httpd-subdirectory-override.patch`
- Modified file: `busybox-1.37.0/networking/httpd.c`
- Functions: `is_open_access()` (new), auth check in `handle_incoming_and_exit()` (modified)
