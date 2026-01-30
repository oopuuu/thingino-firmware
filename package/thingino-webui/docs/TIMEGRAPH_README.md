# Real-Time Time Series Graph Feature

## Overview
This feature provides a web UI page for collecting sensor and system data from the camera via Server-Sent Events (SSE) and displaying it as a real-time time-series graph.

## Files Created

### 1. `tool-timegraph.cgi`
The main UI page that displays the time-series graph and controls.

**Features:**
- Real-time data visualization using Chart.js
- Multiple metrics support (memory, storage, day/night brightness)
- Data collection limits (configurable max points)
- Pause/Resume functionality
- Statistics display (min, max, average)
- Auto-scrolling graph
- Bootstrap-based responsive UI
- Metric selection checkboxes

**Available Metrics:**
- Memory Active
- Memory Free
- Memory Cached
- Memory Buffers
- Overlay Used
- Extras Used
- Exposure Value (EV) - sensor brightness measurement
- GB Gain (Blue/Green AWB gain) - for daynight algorithm
- GR Gain (Red/Green AWB gain) - for daynight algorithm
- Daynight Brightness (%) - calculated brightness percentage

### 2. `json-timegraph-stream.cgi`
Server-side SSE endpoint that streams real-time system data.

**Streaming Data:**
- Current Unix timestamp
- Memory statistics (total, active, buffers, cached, free)
- Overlay filesystem usage
- Extras filesystem usage
- System uptime
- Day/night mode
- Daynight algorithm sensor metrics:
  - EV (Exposure Value) - direct sensor measurement
  - GB Gain (Blue/Green AWB gain) - white balance metric
  - GR Gain (Red/Green AWB gain) - white balance metric
  - Brightness percentage (0-100%) - calculated from EV and thresholds

**Configuration:**
- `STREAM_INTERVAL`: Interval between data updates (default: 2 seconds)
- `STREAM_RETRY_MS`: SSE retry interval in milliseconds

## How It Works

### Client-Side Flow
1. **Connection**: Browser connects to `/x/json-timegraph-stream.cgi` via EventSource
2. **Data Collection**: Receives JSON payloads every 2 seconds
3. **Storage**: Stores data locally in JavaScript (configurable retention)
4. **Rendering**: Updates Chart.js graph in real-time
5. **Statistics**: Calculates and displays min/max/avg for each metric

### Server-Side Flow
1. **Data Generation**: Reads system files (`/proc/meminfo`, `df`, etc.)
2. **JSON Serialization**: Creates JSON payload with current metrics
3. **SSE Streaming**: Sends data to connected clients
4. **Connection Management**: Handles client reconnections with exponential backoff

## Usage

Access the page via the web UI menu under "Tools" > "Time Series Graph" or directly at:
```
http://<camera-ip>/x/tool-timegraph.cgi
```

### Controls
- **Max Points**: Limit the number of data points displayed (10-3600)
- **Auto Scroll**: Enable/disable automatic scrolling to show latest data
- **Pause**: Temporarily stop collecting new data
- **Clear Data**: Remove all collected data and start fresh
- **Metric Checkboxes**: Select which metrics to display

## Customization

### Add More Metrics

Edit `tool-timegraph.cgi` in the `TimeSeriesGraph` class constructor:

```javascript
this.availableMetrics = [
    { key: 'metric_name', label: 'Display Label', color: '#FF6384' },
    // ... add more metrics
];
```

Update `json-timegraph-stream.cgi` to include the new metric in the payload:

```bash
stream_payload() {
  printf '{"time_now":"%s","metric_name":"%s", ...}'
    # ... include your metric value
}
```

### Change Stream Interval

Modify the `STREAM_INTERVAL` environment variable (in seconds):
```bash
STREAM_INTERVAL=5 /x/json-timegraph-stream.cgi
```

## Technical Details

- **Frontend Library**: Chart.js 4.4.0 (via CDN)
- **Protocol**: Server-Sent Events (SSE)
- **Data Format**: JSON
- **Browser Compatibility**: Modern browsers with EventSource support
- **CSS Framework**: Bootstrap 5.3 (matches existing thingino-webui)

## Performance Considerations

- Default: 300 data points, 2-second interval = 10 minutes of history
- Adjustable max points to control memory usage
- Pause functionality to stop consuming updates when not needed
- Auto-reconnection with exponential backoff (5s → 60s max)

## Future Enhancements

Potential additions:
- Export data as CSV
- Custom time range selection
- Moving average/smoothing filters
- Alerting on threshold breaches
- Data persistence (localStorage or server-side)
- Additional sensor data (temperature, light level, etc.)
