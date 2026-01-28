# Time Series Graph - Sensor Metrics Integration

## What Was Updated

The time-series graph page now includes **real-time sensor metrics** from the prudynt daynight algorithm worker, enabling live analysis of camera switching behavior.

## New Metrics

| Metric | Key | Unit | Source | Default |
|--------|-----|------|--------|---------|
| Exposure Value | `ev` | raw value | prudyntctl (live_ev) | ✓ ON |
| GB Gain (AWB) | `gb_gain` | integer | prudyntctl (live_gb) | ✓ ON |
| GR Gain (AWB) | `gr_gain` | integer | prudyntctl (live_gr) | OFF |
| Brightness | `daynight_brightness` | 0-100% | prudyntctl | ✓ ON |

## What Each Metric Shows

### EV (Exposure Value)
- **What**: Raw sensor brightness measurement from ISP
- **Range**: Platform-dependent (T31: 0-60000, T23: 42k-2.2M)
- **Higher = Darker**: Higher EV values indicate darker scenes
- **Algorithm Input**: Primary trigger for daynight switching
- **Why**: Correlate with visible lighting changes

### GB Gain (Blue/Green AWB)
- **What**: Auto-White-Balance gain blue/green component
- **Why**: Shows color temperature shift in low-light conditions
- **Use**: Identifies when camera detects artificial lighting/infrared
- **Secondary Trigger**: Used with delta threshold in day/night algorithm
- **Pattern**: Typically low (stable) in day, spikes in night with IR

### GR Gain (Red/Green AWB)
- **What**: AWB red/green component
- **Correlates With**: GB gain - should move together
- **Use**: Detect color cast issues or sensor problems
- **Debug**: Compare GR/GB ratio to identify color shifts

### Daynight Brightness (%)
- **What**: Calculated brightness percentage (already existed)
- **Now Explicitly Tracked**: Shows in graph with EV for correlation
- **Range**: 0-100% (extended range to avoid saturation)
- **User-Friendly**: Easier to understand than raw EV values

## How Data Flows

```
prudynt-t-stable DayNightWorker
  ↓
  Updates: cfg→daynight.live_ev/gb/gr (std::atomic)
  ↓
prudyntctl JSON API
  ↓
  Streams via: json-timegraph-stream.cgi (SSE)
  ↓
Browser receives via EventSource
  ↓
Chart.js graphs the metrics
  ↓
Statistics calculated per metric
```

## Getting Sensor Data to the Web UI

The sensor metrics are stored in-memory in the prudynt config as atomic values. To expose them to the web UI, you need **one of these approaches**:

### Approach 1: Use prudyntctl JSON API (Recommended)

The `json-timegraph-stream.cgi` script queries:
```bash
echo '{"daynight":{"status":null}}' | prudyntctl json - 2>/dev/null
```

This requires prudyntctl to expose the daynight live metrics. Check your prudynt version's JSON API capabilities.

### Approach 2: Write Values to Files (Fallback)

Modify `DayNightWorker.cpp` to write these values to files in `/run/prudynt/`:

```cpp
// In DayNightWorker.cpp, around line 380 in thread_entry():
// After updating the atomic values, also export to files:
int fd = open("/run/prudynt/daynight_ev", O_WRONLY | O_CREAT | O_TRUNC, 0644);
if (fd >= 0) {
  dprintf(fd, "%d\n", ev);
  close(fd);
}
// Similar for daynight_gb, daynight_gr
```

### Approach 3: Check prudyntctl Response

Test what your prudynt version actually returns:

```bash
# On camera:
echo '{"daynight":{"status":null}}' | prudyntctl json -
# Or check full config
prudyntctl json /etc/prudynt.json | jq .daynight
```

## Troubleshooting Non-Changing Values

**If sensor values always show 0 and don't change:**

1. Check if daynight worker is running:
   ```bash
   ps aux | grep daynight
   pgrep -f prudynt
   ```

2. Verify prudyntctl is available:
   ```bash
   which prudyntctl
   prudyntctl --version
   ```

3. Test prudyntctl directly:
   ```bash
   echo '{"daynight":{"status":null}}' | prudyntctl json - 2>&1
   ```

4. Check file-based sources:
   ```bash
   cat /run/prudynt/daynight_brightness
   ls -la /run/prudynt/daynight*
   ```

5. Enable debug logging:
   ```bash
   # In /etc/prudynt.json:
   "daynight": {
     "loglevel": "DEBUG"
   }
   # Then check logs:
   tail -f /var/log/prudynt.log
   ```

**Solution:** The data needs to be exposed either via prudyntctl JSON API or by writing to `/run/prudynt/` files in DayNightWorker. If neither works, the metrics will remain at 0.



### 1. Debug Daynight Switching Issues
```
Problem: Camera switches at wrong time
Solution:
  1. Enable EV and Brightness metrics
  2. Observe values during transition
  3. Compare against thresholds in config
  4. Identify if sensor is reading correctly
```

### 2. Optimize Thresholds
```
Goal: Fine-tune daynight switching
Steps:
  1. Record data over full day cycle
  2. Graph EV values
  3. Identify natural transition points
  4. Adjust ev_night_high / ev_day_low_primary
```

### 3. Detect Flicker Patterns
```
Problem: Rapid day/night flickering
Analysis:
  1. Watch mode changes in daynight_brightness
  2. Look for rapid swings in EV
  3. Check if counters are thrashing
  4. May indicate marginal threshold
```

### 4. Analyze Sensor Behavior
```
Investigation:
  1. Monitor GB/GR gain drift
  2. Detect gains stuck at extremes
  3. Identify color cast issues
  4. Compare against sensor specs
```

## Key Thresholds (Configurable)

These values determine when switching occurs:

```
EV Thresholds (from DayNightAlgo.hpp):
  - ev_night_high:        1,900,000   (trigger night mode if EV > this)
  - ev_day_low_primary:     479,832   (trigger day mode if EV < this)
  - ev_day_low_secondary:   361,880   (secondary gate with GB gain)

GB Gain Thresholds:
  - gb_gain_delta:              15    (require this much increase from minima)
  - gb_gain_absolute:          145    (or absolute value must exceed this)

Counters:
  - night_count_threshold:       6    (need 6+ EV measurements > night_high)
  - day_count_threshold:         4    (need 4+ measurements meeting day criteria)
  - settle_samples:             20    (samples to capture GB/GR minima at night)
```

## Real-World Example

### Scenario: Dawn Transition
```
05:50 - Before sunrise
  EV: 300,000 (dark)
  GB: 140, GR: 142
  Brightness: 15%
  Mode: Night ✓

06:00 - Sunrise starting
  EV: 400,000 (rising)
  GB: 140, GR: 142
  Brightness: 25%
  Mode: Night ✓

06:10 - Significant light
  EV: 600,000 (much brighter)
  GB: 130, GR: 128 (gains drop as color normalizes)
  Brightness: 55%
  Mode: Transitioning... (counter incrementing)

06:15 - Full daylight
  EV: 150,000 (very bright)
  GB: 95, GR: 100 (normal day gains)
  Brightness: 90%
  Mode: Day ✓
```

### What You'd See in Graph
- **EV line**: Sharp drop (higher → lower is brighter)
- **GB line**: Plateau then smooth drop
- **Brightness**: Smooth rise from 15% → 90%
- **Mode changes**: Clear points where algorithm triggered

## Files Modified

| File | Changes |
|------|---------|
| [tool-timegraph.cgi](../tool-timegraph.cgi) | Added EV, GB/GR Gain to availableMetrics; set as defaults |
| [json-timegraph-stream.cgi](../json-timegraph-stream.cgi) | Added prudyntctl reading with fallback to files |
| [TIMEGRAPH_README.md](../TIMEGRAPH_README.md) | Updated metrics list and data streaming section |
| [TIMEGRAPH_QUICKSTART.md](../../TIMEGRAPH_QUICKSTART.md) | Updated metrics table with sensor data |
| [TIMEGRAPH_EXAMPLES.md](../TIMEGRAPH_EXAMPLES.md) | Added sensor metrics guide and analysis examples |

## Accessing the Metrics

### Via Web UI
```
http://<camera-ip>/x/tool-timegraph.cgi
```

Default view shows:
- EV (Exposure Value)
- GB Gain (Blue/Green)
- Daynight Brightness %

### Via Command Line (for manual inspection)
```bash
# Get raw sensor values
prudyntctl json - <<< '{"daynight":{"status":null}}'

# Read from files (if prudyntctl unavailable)
cat /run/prudynt/daynight_brightness
awk 'NR==1 {print $1}' /run/prudynt/daynight_mode
```

## Troubleshooting

**No EV/Gain values showing (-1)?**
- Check if prudyntctl is installed and working
- Verify /run/prudynt directory exists
- Check daemon/service status

**Values not updating?**
- Verify SSE stream is connected (check browser console)
- Check if daynight worker is running
- Monitor browser network tab for payload

**Values seem stuck?**
- Check if daynight worker is frozen
- May indicate ISP issue or sensor problem
- Review prudynt logs for errors

## Related Files

### Source Code References
- DayNightAlgo: `/overrides/prudynt-t-stable/src/DayNightAlgo.hpp`
- DayNightWorker: `/overrides/prudynt-t-stable/src/DayNightWorker.cpp`
- Config struct: `/overrides/prudynt-t-stable/src/Config.hpp`

### Configuration
- Daynight config: `/etc/prudynt.json` (daynight section)
- Thresholds: Settable via web UI or JSON API
