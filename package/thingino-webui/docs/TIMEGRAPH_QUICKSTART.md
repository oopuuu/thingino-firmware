# Time Series Graph - Quick Start Guide

## What Was Created

Two new pages in your thingino-webui at `/package/thingino-webui/files/www/x/`:

### 1. **tool-timegraph.cgi** - The UI Page
The main interface where users interact with the time-series graph.

**Key Components:**
```
┌─────────────────────────────────────────────────────┐
│  Real-Time Sensor Data Graph                        │
├─────────────────────────────────────────────────────┤
│  ● Connected - Streaming data...                    │  ← Status
├─────────────────────────────────────────────────────┤
│  [Max Points: 300] [✓] Auto Scroll [Pause] [Clear]  │  ← Controls
├─────────────────────────────────────────────────────┤
│  Metrics to Display:                                │
│  [✓] Memory Active    [✓] Memory Free               │
│  [✓] Memory Cached    [ ] Memory Buffers            │  ← Metric Toggles
│  [ ] Overlay Used     [ ] Extras Used               │
│  [ ] Daynight Brightness                            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ╔════════════════════════════════════════════╗    │
│  ║                                            ║    │
│  ║         [Chart.js Time Series Graph]       ║    │
│  ║                                            ║    │
│  ╚════════════════════════════════════════════╝    │  ← Graph Canvas
│                                                     │
├─────────────────────────────────────────────────────┤
│  Memory Active         Memory Free                  │
│  Current: 45000        Current: 25000               │
│  Min: 42000  Max: 48000                             │  ← Statistics
│  Avg: 45234                                         │
│                                                     │
│  Memory Cached         Daynight Brightness          │
│  ...                                                │
└─────────────────────────────────────────────────────┘
```

### 2. **json-timegraph-stream.cgi** - The Data Stream
Server-Sent Events endpoint that streams data to the UI.

**Connection Flow:**
```
Browser                         Camera
   │                              │
   ├─ EventSource('/x/json-      │
   │   timegraph-stream.cgi')     │
   │─────────────────────────────→│
   │                         Every 2 sec:
   │←─ data: {"time_now":"...", "mem_active":"45000"...}
   │←─ data: {"time_now":"...", "mem_active":"45100"...}
   │←─ data: {"time_now":"...", "mem_active":"45200"...}
   │                         ...continues...
```

## How It Works

### Behind the Scenes (Server)
```bash
# Every 2 seconds, the CGI script:
1. Reads /proc/meminfo              → gets memory stats
2. Runs df command                  → gets disk usage
3. Queries prudyntctl               → gets sensor/daynight metrics (EV, gains)
4. Reads /run/prudynt/              → gets day/night settings & brightness
5. Creates JSON payload             → {"time_now":"1234567890", "ev":"45000"...}
6. Sends via SSE                    → client receives data
7. Repeats...
```

### Behind the Scenes (Client)
```javascript
// JavaScript continuously:
1. Connects to SSE endpoint via EventSource
2. Receives JSON data packets
3. Stores data in memory (up to max points)
4. Calculates min/max/average per metric
5. Updates Chart.js graph
6. Refreshes statistics display
7. Auto-reconnects on disconnect
```

## Accessing the Page

**URL:**
```
http://<camera-ip>/x/tool-timegraph.cgi
```

**Or from the web UI menu:**
- Tools → Time Series Graph

## Features Explained

### 📊 Real-Time Graph
- Shows 10 different metrics (system + sensor data)
- Updates every 2 seconds
- Click metric checkboxes to show/hide lines
- **Default displayed:** EV, GB Gain, and Daynight Brightness (optimal for daynight algorithm analysis)

### 🕐 Time Control
- **Max Points**: How many data points to keep (300 = ~10 min)
- **Auto Scroll**: Automatically shows latest data
- **Pause**: Stop receiving new data temporarily

### 📈 Statistics Display
- **Min**: Lowest value recorded
- **Max**: Highest value recorded
- **Avg**: Average of all values
- **Current**: Last received value

### 🔌 Connection Status
- Green "●" = Connected and streaming
- Red "●" = Disconnected, trying to reconnect

## Default Metrics

| Metric | Unit | Source | Default |
|--------|------|--------|---------|
| Memory Active | KiB | /proc/meminfo | - |
| Memory Free | KiB | /proc/meminfo | - |
| Memory Cached | KiB | /proc/meminfo | - |
| Memory Buffers | KiB | /proc/meminfo | - |
| Overlay Used | KiB | df (overlay mount) | - |
| Extras Used | KiB | df (opt mount) | - |
| **Exposure Value (EV)** | **raw sensor value** | **prudyntctl / daynight worker** | **✓ ON** |
| **GB Gain (Blue/Green)** | **AWB gain** | **prudyntctl / daynight worker** | **✓ ON** |
| **GR Gain (Red/Green)** | **AWB gain** | **prudyntctl / daynight worker** | **OFF** |
| **Daynight Brightness** | **0-100%** | **prudyntctl / calculated** | **✓ ON** |

**Note:** The sensor metrics (EV, GB Gain, GR Gain, Brightness %) are specifically useful for analyzing the daynight switching algorithm behavior.

## Customization

### Add a New Metric

**Step 1:** Add to the metric list in `tool-timegraph.cgi`:
```javascript
this.availableMetrics = [
    // ... existing metrics ...
    { key: 'cpu_temp', label: 'CPU Temperature (°C)', color: '#FF5733' }
];
```

**Step 2:** Add to the data stream in `json-timegraph-stream.cgi`:
```bash
stream_payload() {
  printf '{"time_now":"%s","cpu_temp":"%d",...}'
    "$(date +%s)"
    "$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print $1/1000}')"
    # ... rest of metrics
}
```

### Change Stream Interval

Make it faster or slower:
```bash
# Slower updates (every 5 seconds)
STREAM_INTERVAL=5 /x/json-timegraph-stream.cgi

# Faster updates (every 1 second)
STREAM_INTERVAL=1 /x/json-timegraph-stream.cgi
```

## Technical Stack

| Component | What | Source |
|-----------|------|--------|
| **Frontend** | Chart.js 4.4.0 | CDN |
| **Protocol** | Server-Sent Events (SSE) | HTML5 |
| **Data Format** | JSON | Native |
| **Server** | Shell script (sh) | /bin/sh |
| **CSS** | Bootstrap 5.3 | Existing thingino-webui |
| **Template** | Haserl | Existing thingino-webui |

## Performance Notes

- **Memory Usage**: ~1-2MB (storing 300 data points + UI)
- **Bandwidth**: ~200 bytes every 2 seconds = ~100 bytes/sec
- **CPU Impact**: Minimal (parsing JSON + updating chart)
- **Reconnection**: Auto-reconnects with backoff (5s → 60s)

## Troubleshooting

### Graph not updating?
1. Check browser console (F12) for errors
2. Verify network connection (check Network tab)
3. Confirm `/x/json-timegraph-stream.cgi` is accessible
4. Check if camera files readable (`/proc/meminfo`, `df`)

### No data points?
1. Enable at least one metric (check checkbox)
2. Wait a few seconds for data to arrive
3. Check stream status indicator

### Disconnected status?
1. Normal after a few seconds of inactivity
2. Will auto-reconnect when page becomes active
3. Check `/x/json-timegraph-stream.cgi` is executable

## File Locations

```
/package/thingino-webui/files/www/x/
├── tool-timegraph.cgi              ← Main UI (11KB)
├── json-timegraph-stream.cgi       ← Data stream (1.5KB)
└── TIMEGRAPH_README.md             ← Full documentation
```

Both files are executable shell scripts that integrate with the existing thingino-webui system.
