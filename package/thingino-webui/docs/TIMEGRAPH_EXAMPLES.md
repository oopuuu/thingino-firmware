# Time Series Graph - Code Examples

## Understanding the Daynight Sensor Metrics

The page now includes three key metrics from the prudynt daynight algorithm worker:

### Exposed Metrics

1. **EV (Exposure Value)** - `ev`
   - Raw sensor brightness measurement
   - Higher values = darker scene
   - Used by daynight algorithm to detect night conditions
   - Thresholds:
     - `ev_night_high` (~1,900,000): Triggers night mode
     - `ev_day_low_primary` (~479,832): Triggers day mode

2. **GB Gain (Blue/Green)** - `gb_gain`
   - AWB (Auto White Balance) blue/green component
   - Indicates color temperature shift in low light
   - Minima captured during night settle period
   - Used as secondary trigger with delta threshold

3. **GR Gain (Red/Green)** - `gr_gain`
   - AWB (Auto White Balance) red/green component
   - Similar to GB gain, indicates color shift
   - Available for analysis and tuning

4. **Daynight Brightness (%)** - `daynight_brightness`
   - Calculated percentage (0-100%)
   - Maps EV range to user-friendly scale
   - Extended range to avoid saturation

### Reading from Prudynt

The `json-timegraph-stream.cgi` reads these values in this order:
```bash
# First, try prudyntctl (preferred - real-time)
daynight_json=$(prudyntctl json - 2>/dev/null <<< '{"daynight":{"status":null}}')
ev=$(echo "$daynight_json" | grep -o '"live_ev":[^,}]*' | cut -d: -f2)
gb_gain=$(echo "$daynight_json" | grep -o '"live_gb":[^,}]*' | cut -d: -f2)
gr_gain=$(echo "$daynight_json" | grep -o '"live_gr":[^,}]*' | cut -d: -f2)

# Fallback to file read if prudyntctl not available
[ "$brightness_pct" = "-1" ] && brightness_pct=$(awk '{print $1}' /run/prudynt/daynight_brightness)
```

## Analyzing Daynight Switching

To debug why daynight switching is happening at unexpected times:

**1. Enable all three metrics in the UI:**
   - Check: EV
   - Check: GB Gain
   - Check: Daynight Brightness

**2. Observe the graph as lighting conditions change:**
   - Watch EV value as brightness changes
   - Note GB Gain spikes/changes
   - Correlate with brightness % and mode changes
   - Compare against configured thresholds

**3. Use statistics panel to see ranges:**
   - Min/Max values of EV over observation period
   - Average brightness percentage
   - Check if gains are fluctuating or stable

---

## Adding Custom Metrics

### Example 1: Adding CPU Temperature

**1. Update `tool-timegraph.cgi` - Add to availableMetrics:**

Find this section in the `TimeSeriesGraph` constructor:
```javascript
this.availableMetrics = [
    { key: 'mem_active', label: 'Memory Active (KiB)', color: '#FF6384' },
    { key: 'mem_free', label: 'Memory Free (KiB)', color: '#36A2EB' },
    // ... existing metrics ...
```

Add your new metric:
```javascript
    { key: 'cpu_temp', label: 'CPU Temperature (°C)', color: '#FF5733' },
```

**2. Update `json-timegraph-stream.cgi` - Add to stream_payload:**

Find the printf statement and add your metric:
```bash
stream_payload() {
  # Get CPU temperature (example for thermal zone 0)
  cpu_temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f", $1/1000}' || echo "0")

  printf '{"time_now":"%s","mem_total":"%d",...,"cpu_temp":"%.1f"}' \
    "$(date +%s)" \
    "$(awk '/^MemTotal:/{print $2}' /proc/meminfo)" \
    # ... existing metrics ...
    "$cpu_temp"
}
```

### Example 2: Adding Load Average

**In `tool-timegraph.cgi`:**
```javascript
{ key: 'load_avg', label: 'Load Average (1min)', color: '#00AA00' },
```

**In `json-timegraph-stream.cgi`:**
```bash
stream_payload() {
  load_avg=$(awk '{print $1}' /proc/loadavg)

  printf '{"time_now":"%s",...,"load_avg":"%.2f"}' \
    "$(date +%s)" \
    # ... existing metrics ...
    "$load_avg"
}
```

### Example 3: Adding Custom Sensor Data

If you have a sensor reading from a file or command:

**In `tool-timegraph.cgi`:**
```javascript
{ key: 'humidity', label: 'Humidity (%)', color: '#0099FF' },
{ key: 'temperature', label: 'Ambient Temperature (°C)', color: '#FF6600' },
```

**In `json-timegraph-stream.cgi`:**
```bash
stream_payload() {
  # Example: read from JSON sensor file
  humidity=$(jct /etc/sensor.json get "humidity" 2>/dev/null || echo "0")
  temperature=$(jct /etc/sensor.json get "temperature" 2>/dev/null || echo "0")

  printf '{"time_now":"%s",...,"humidity":"%.1f","temperature":"%.1f"}' \
    "$(date +%s)" \
    # ... existing metrics ...
    "$humidity" \
    "$temperature"
}
```

## Modifying Data Retention

### Default: 300 Points

The page loads with this setting, but users can adjust at runtime via the "Max Points" input.

To change the default in `tool-timegraph.cgi`:
```javascript
this.maxPoints = 300;  // Change this number
```

For 24 hours of data at 2-second intervals:
```
24 hours × 3600 seconds = 86400 seconds
86400 ÷ 2 = 43200 data points needed
```

### Custom Example: 1-Hour History

```javascript
this.maxPoints = 1800;  // 1800 * 2 seconds = 3600 seconds = 1 hour
```

## Changing Stream Interval

The default interval is 2 seconds. To change it:

**Method 1: Modify in `json-timegraph-stream.cgi`**
```bash
STREAM_INTERVAL="${STREAM_INTERVAL:-5}"  # Change 5 to desired seconds
```

**Method 2: Set environment variable before running**
```bash
export STREAM_INTERVAL=1  # 1 second updates
```

**Method 3: Modify `tool-timegraph.cgi` client-side**
Find the startStream function and adjust reconnection timing if needed.

## Advanced: Connecting External Data Sources

### Example: Integration with HTTP Sensor API

Modify the server-side to fetch data from another source:

```bash
stream_payload() {
  # Fetch from external API (e.g., weather API)
  external_temp=$(curl -s "http://localhost:8080/api/temperature" | jq '.temp' 2>/dev/null || echo "0")

  printf '{"time_now":"%s",...,"external_temp":"%.1f"}' \
    "$(date +%s)" \
    # ... existing metrics ...
    "$external_temp"
}
```

**Warning:** This could slow down the stream if the API is slow. Consider caching or async calls.

## JavaScript Class Methods Reference

The `TimeSeriesGraph` class has these public methods (can be called from browser console):

```javascript
// Clear all data
window.timeSeriesGraph.clearData()

// Pause data collection
window.timeSeriesGraph.isPaused = true

// Resume data collection
window.timeSeriesGraph.isPaused = false

// Change max points programmatically
window.timeSeriesGraph.maxPoints = 500
window.timeSeriesGraph.trimData()
window.timeSeriesGraph.updateChart()

// Get current data
console.log(window.timeSeriesGraph.data)
console.log(window.timeSeriesGraph.stats)

// Manually trigger chart update
window.timeSeriesGraph.updateChart()

// Close connection
window.timeSeriesGraph.destroy()

// Restart connection
window.timeSeriesGraph.startStream()
```

## CSS Customization

### Change Chart Height

In `tool-timegraph.cgi`, find the CSS and modify:
```css
#chart-container {
    position: relative;
    height: 400px;  /* Change this value */
    margin-bottom: 2rem;
}
```

For a larger graph:
```css
height: 600px;  /* Bigger graph */
```

### Custom Color Scheme

Edit the metric colors in the availableMetrics array:
```javascript
{ key: 'mem_active', label: 'Memory Active (KiB)', color: '#FF6384' }
//                                                        ^^^^^^^^^ - This is the color (hex)
```

Color examples:
- `#FF6384` - Red/Pink
- `#36A2EB` - Blue
- `#FFCE56` - Yellow
- `#4BC0C0` - Teal
- `#9966FF` - Purple
- `#FF9F40` - Orange
- `#C9CBCF` - Gray

## Debugging

### Enable Console Logging

The script already logs to browser console. Check with F12:

```javascript
// In browser console, enable verbose logging:
window.timeSeriesGraph.verbose = true;

// See raw SSE events:
// The EventSource is stored in: window.timeSeriesGraph.eventSource
```

### Inspect Streaming Data

```javascript
// See all collected data points
window.timeSeriesGraph.data

// See statistics
window.timeSeriesGraph.stats

// See enabled metrics
window.timeSeriesGraph.enabledMetrics

// See current chart datasets
window.timeSeriesGraph.chart.data.datasets
```

### Check Server-Side Issues

Test the SSE endpoint directly:
```bash
curl -v http://localhost/x/json-timegraph-stream.cgi
```

Should show:
```
Content-Type: text/event-stream
Cache-Control: no-cache
Connection: keep-alive

retry: 2000
data: {"time_now":"1234567890","mem_total":"...", ...}

retry: 2000
data: {"time_now":"1234567891","mem_total":"...", ...}
```

If you see nothing or errors, check that:
1. File is executable: `ls -l json-timegraph-stream.cgi`
2. `/proc/meminfo` is readable: `cat /proc/meminfo`
3. `df` command works: `df`
4. `/run/prudynt/` directory exists (or handle gracefully)

## Performance Tips

### For High-Frequency Updates

If streaming at 1-second intervals with many metrics:

1. Reduce max points:
```javascript
this.maxPoints = 100;  // Smaller history
```

2. Reduce Chart.js animation:
```javascript
this.chart.update('none');  // Already done - no animation
```

3. Update chart less frequently:
```javascript
// In addDataPoint(), add a counter:
if (this.updateCounter++ % 3 === 0) {
    this.updateChart();  // Update every 3 data points
}
```

### For Low-Power Devices

1. Increase stream interval:
```bash
STREAM_INTERVAL=5  # 5-second updates instead of 2
```

2. Reduce displayed metrics to essentials only

3. Lower max points:
```javascript
this.maxPoints = 150;  // 5 minutes at 2-second intervals
```

## Data Export (Future Enhancement)

To add CSV export, add this button to the HTML:
```html
<button class="btn btn-sm btn-secondary" id="export-csv">Export CSV</button>
```

And this JavaScript:
```javascript
document.getElementById('export-csv').addEventListener('click', () => {
    let csv = 'Time,' + Array.from(this.enabledMetrics).join(',') + '\n';

    for (let i = 0; i < this.chart.data.labels.length; i++) {
        csv += this.chart.data.labels[i] + ',';
        this.enabledMetrics.forEach(metric => {
            csv += (this.data[metric]?.[i] || '') + ',';
        });
        csv += '\n';
    }

    const blob = new Blob([csv], {type: 'text/csv'});
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'timeseries-' + Date.now() + '.csv';
    a.click();
});
```

## Security Notes

- SSE endpoint streams unencrypted data (same as existing heartbeat)
- No authentication required (uses same pattern as other monitoring pages)
- Data is collected client-side and not stored on server
- HTTPS recommended for production deployments
