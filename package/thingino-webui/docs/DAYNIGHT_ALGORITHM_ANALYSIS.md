# Day/Night Algorithm Analysis

## Current Algorithm Issues

### 1. **Broken GB/GR Gain Dependency**
The algorithm in `DayNightAlgo.hpp` relies on AWB gain values (gb_gain, gr_gain) that are **always 0** on T23 platforms:

```cpp
// Day path - line 92-110 in DayNightAlgo.hpp
bool have_gb = (sig.gb_gain > 0);
bool gb_delta_ok = have_gb && (sig.gb_gain > s.gb_gain_record + p.gb_gain_delta);
```

**Problem**: Since `gb_gain` is always 0, the algorithm falls back to EV-only mode, but the thresholds are calibrated for a dual-signal approach.

### 2. **Platform-Specific EV Ranges Not Calibrated**
Current hardcoded thresholds from DayNightWorker.cpp lines 64-85:

```cpp
#if defined(PLATFORM_T23)
  p.EVmin = 42857;
  p.EVmax = 2227731;
#elif defined(PLATFORM_T31)
  p.EVmin = 0;
  p.EVmax = 60000;
```

**Observed Reality**:
- T23 SC2336 sensor produces EV values in range ~1000 - 30000 (much smaller than the 42857-2227731 range)
- This causes brightness percentage calculations to be completely wrong
- Thresholds `ev_night_high` (1900000) and `ev_day_low_primary` (479832) are far outside actual sensor range

### 3. **Inverted EV Semantics Confusion**
The code comments and variable names suggest higher EV = brighter, but **the opposite is true**:
- **Lower EV values = Brighter conditions** (shorter exposure time)
- **Higher EV values = Darker conditions** (longer exposure time)

Algorithm logic at line 84-88:
```cpp
// Night path: EV high for N samples
if (sig.ev > p.ev_night_high) {
  // Switch to night
}
```

This is **correct** (high EV = dark = night), but the thresholds are calibrated wrong.

### 4. **Brightness Percentage Calculation**
Lines 108-130 in DayNightWorker.cpp:

```cpp
static inline int brightness_percent_from_ev(const Profile &pr,
                                             const DayNightAlgo::Params &params,
                                             int ev) {
  // Maps EV to 0-100% using ev_night_high and ev_day_low_primary
  // But these values are wrong for actual sensor range!
}
```

**Result**: Brightness always shows 8% regardless of actual lighting conditions.

## Raw ISP Sensor Data Pipeline (NEW)

### Added Metrics Exported from prudynt:
1. **`total_gain`** - ISP total gain (analog + digital combined)
2. **`ae_luma`** - Auto-exposure luma value
3. **`awb_color_temp`** - AWB color temperature (T31 only, -1 on T23)

### Data Flow:
```
ISP Hardware (SC2336)
  ↓
IMP SDK Functions:
  - IMP_ISP_Tuning_GetEVAttr() → ev
  - IMP_ISP_Tuning_GetTotalGain() → total_gain
  - IMP_ISP_Tuning_GetAeLuma() → ae_luma
  - IMP_ISP_Tuning_GetAwbHist() → gb/gr (returns 0)
  ↓
DayNightWorker.cpp (lines 369-376)
  → Stores in cfg->daynight.live_* atomics
  ↓
JsonAPI.cpp handle_daynight() (lines 1047-1072)
  → Exposes via JSON API
  ↓
json-timegraph-stream.cgi
  → SSE stream to browser
  ↓
tool-sensor-data.html
  → Real-time Chart.js visualization
```

## What Actually Works

### Reliable Metrics:
1. **EV (Exposure Value)** - Changes dynamically with lighting
   - Observed range: ~1000 (bright) to ~30000 (dark)
   - Responsive and accurate

2. **Total Gain** - Should respond to low light
   - Needs testing to verify range

3. **AE Luma** - Auto-exposure brightness measurement
   - Needs testing to verify range

### Unreliable/Broken Metrics:
1. **GB/GR Gains** - Always 0 (ISP limitation)
2. **Brightness %** - Derived from wrong EV ranges
3. **AWB Color Temp** - Not available on T23

## Recommended Algorithm Fix

### Step 1: Calibrate Actual Sensor Ranges
Use the data collector to gather:
- Minimum EV in bright daylight
- Maximum EV in complete darkness
- Total gain behavior across lighting conditions
- AE luma behavior across lighting conditions

### Step 2: Use Multiple Signals
Instead of relying on broken GB gains, use:
- **EV** (primary) - for exposure time
- **Total Gain** (secondary) - to detect when ISP is boosting signal
- **AE Luma** (tertiary) - for scene brightness estimate

### Step 3: Simple Threshold Algorithm
```
Night Condition: (ev > threshold_high) AND (total_gain > gain_threshold)
Day Condition: (ev < threshold_low) AND (total_gain < gain_threshold)
```

### Step 4: Anti-Flap with Hysteresis
Keep existing counter-based anti-flap logic but with calibrated thresholds.

## Files Modified

1. **Config.hpp** - Added live_total_gain, live_ae_luma, live_awb_color_temp atomics
2. **DayNightWorker.cpp** - Read additional ISP values, export to config
3. **JsonAPI.cpp** - Expose new values in daynight status JSON
4. **json-timegraph-stream.cgi** - Include new metrics in SSE stream
5. **tool-sensor-data.html** - Display and graph new metrics
6. **imp_hal.cpp** - Documented AWB gain limitation

## Next Steps

1. **Rebuild prudynt** with new sensor data exports
2. **Collect data** across full day/night cycle
3. **Analyze CSV export** to determine actual sensor ranges
4. **Recalibrate thresholds** based on real data
5. **Implement improved algorithm** using total_gain + ev
