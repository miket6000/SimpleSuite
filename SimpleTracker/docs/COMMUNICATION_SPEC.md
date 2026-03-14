# Ground Station USB Communication Specification

This document describes the USB serial protocol used by the PC application to communicate with a SimpleTracker module acting as a Ground Station. It is intended to be a complete reference for implementing the PC-side software.

---

## 1. Transport Layer

| Parameter       | Value                                         |
|-----------------|-----------------------------------------------|
| Interface       | USB CDC (Virtual COM Port)                    |
| Line ending     | `\n` (newline, 0x0A)                          |
| Command delimiter | Space (` `)                                 |
| Max command length | 31 characters (including terminator)        |
| Encoding        | ASCII                                         |

All commands are sent as a single line terminated with `\n`. Responses are returned immediately as bare ASCII strings with **no trailing newline or delimiter**. There is no prompt and no character echo in the default (non-interactive) mode.

> **Note:** An interactive debugging mode exists (`I` command) which enables a `\n> ` prompt and character echo. This mode is for human use with a terminal emulator and should **not** be used by the PC application — it adds extra output that will interfere with automated parsing.

---

## 2. USB Command Reference

### 2.1 `UID` — Get Ground Station UID

Returns the 8-character hexadecimal UID of the connected Ground Station.

| Field     | Value    |
|-----------|----------|
| Command   | `UID\n`  |
| Parameters | None    |
| Response  | 8 hex chars, e.g. `1a2b3c4d` |

**Example:**
```
TX: UID
RX: 1a2b3c4d
```

---

### 2.2 `SCAN` — Initiate Device Discovery

Broadcasts a UID discovery request on the current (discovery) channel. All remote trackers that hear the broadcast will respond with their UIDs after a random delay (0–5 seconds in 500 ms slots) to avoid RF collisions.

| Field     | Value        |
|-----------|--------------|
| Command   | `SCAN\n`     |
| Parameters | None        |
| Response  | `OK`         |

The SCAN command returns `OK` immediately. You must then poll with the `D` command to retrieve results.

**Over-the-air effect:** The Ground Station transmits a LoRa frame containing:
```
<ground_station_uid> &ffffffffU
```
(Broadcast address `ffffffff`, command character `U`.)

---

### 2.3 `D` — Read Discovery Results

Reads the results of a preceding `SCAN`.

| Field     | Value    |
|-----------|----------|
| Command   | `D\n`    |
| Parameters | None    |
| Response  | See below |

**Response formats:**

| State                        | Response                                     |
|------------------------------|----------------------------------------------|
| No scan initiated            | `NONE`                                       |
| Scan in progress (not done)  | `WAIT <count>` — `<count>` is responses so far |
| Scan complete                | `<count> <uid1>,<rssi1> <uid2>,<rssi2> ...`  |

- The discovery window is **6 seconds** (`DISCOVERY_WINDOW_MS`).
- A maximum of **10** devices can be discovered per scan (`DISCOVERY_MAX_RESPONSES`).
- RSSI values are signed integers (e.g. `-85`).
- Reading a complete result resets the discovery state; a subsequent `D` without a new `SCAN` returns `NONE`.

**Example (2 devices found):**
```
TX: SCAN
RX: OK

TX: D
RX: WAIT 1

TX: D
RX: 2 a1b2c3d4,-72 e5f6a7b8,-91
```

**Recommended polling strategy:** After sending `SCAN`, wait ~1 second, then poll `D` every 1–2 seconds. When the response no longer starts with `WAIT`, parsing is complete.

---

### 2.4 `PAIR` — Pair with a Remote Tracker

Instructs the Ground Station to command a specific remote tracker to switch to a dedicated LoRa channel and begin transmitting GPS data. The Ground Station will also switch to that channel once the remote tracker ACKs.

| Field       | Value                                |
|-------------|--------------------------------------|
| Command     | `PAIR <uid> <freq> <sf> <bw>\n`     |
| Parameters  | 4, space-separated (see below)       |
| Response    | `OK` or `ERR`                        |

**Parameters:**

| Parameter | Type     | Description                              | Example       |
|-----------|----------|------------------------------------------|---------------|
| `uid`     | string   | 8-char hex UID of the target tracker      | `a1b2c3d4`    |
| `freq`    | uint32   | Frequency in Hz                           | `434500000`   |
| `sf`      | uint8    | Spreading factor (raw enum value, see §4) | `9`           |
| `bw`      | uint8    | Bandwidth (raw enum value, see §4)        | `4`           |

**Response:** `OK` means the command was queued for LoRa transmission. `ERR` means a parameter was missing or `freq` was zero.

**Over-the-air effect:** The Ground Station transmits:
```
<ground_station_uid> &<target_uid>T<freq>,<sf>,<bw>
```

**What happens next:**
1. The remote tracker receives the `T` command, stores the pending config, and immediately ACKs on the discovery channel:
   ```
   <tracker_uid> &<ground_station_uid>TACK
   ```
2. After the ACK transmission completes, the tracker applies the new LoRa config and enters `MODE_TRACKER` (begins transmitting GPS data).
3. The Ground Station receives the ACK, applies the same LoRa config, and re-enters receive mode on the new channel.

**Important:** The Ground Station stores `pendingFreq/SF/BW` locally when you send `PAIR`. The config switch happens automatically upon receiving the ACK — no further USB command is needed.

**Example:**
```
TX: PAIR a1b2c3d4 434500000 9 4
RX: OK
```

---

### 2.5 `T` — Raw LoRa Transmit

Sends an arbitrary LoRa command to a specific tracker or broadcast address.

| Field       | Value                                 |
|-------------|---------------------------------------|
| Command     | `T <payload>\n`                       |
| Parameters  | 1 (the payload string, min 10 chars)  |
| Response    | `OK` or `ERR`                         |

The `<payload>` must be at least 10 characters and follows the on-air message format (see §3). The Ground Station's UID is automatically prepended and a space separator inserted before transmission.

**Example — send a UID query to broadcast:**
```
TX: T &ffffffffU
RX: OK
```

**Example — request voltage from a specific tracker:**
```
TX: T &a1b2c3d4V
RX: OK
```

**On-air frame produced:**
```
<ground_station_uid> &ffffffffU
```

---

### 2.6 `R` — Read Last Received LoRa Message

Returns the last LoRa message received by the Ground Station. This is used to read tracking data, ACKs, voltage responses, and any other inbound LoRa messages.

| Field     | Value    |
|-----------|----------|
| Command   | `R\n`    |
| Parameters | None    |
| Response  | The last received message (see below) |

**Response formats depend on message type:**

| Message Type          | Response Format                                           |
|-----------------------|-----------------------------------------------------------|
| GPS tracking data     | `<raw_gps_sentence> <rssi>`                               |
| Voltage response      | `<tracker_uid> &<our_uid>V<voltage_mv>`                   |
| PAIR ACK              | `<tracker_uid> &<our_uid>TACK`                            |
| No message yet        | Empty / null string                                       |

**GPS tracking data example:**
```
TX: R
RX: $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47 -72
```

The RSSI (e.g. `-72`) is appended with a space separator to the raw GPS NMEA sentence.

**Polling strategy for tracking:** Once paired, poll `R` at your desired update rate (e.g. every 1–2 seconds). The tracker transmits GPS data approximately every other GPS fix cycle.

---

### 2.7 `L` — Read Last GPS Sentence (Local)

Returns the last GPS NMEA sentence received by the Ground Station's own GPS module (if present).

| Field     | Value    |
|-----------|----------|
| Command   | `L\n`    |
| Parameters | None    |
| Response  | Raw NMEA sentence string |

---

### 2.8 `C` — Channel Switch (Manual)

Manually changes the Ground Station's LoRa radio parameters without sending any over-the-air command. Use this to return to the discovery channel or switch to an arbitrary channel.

| Field       | Value                        |
|-------------|------------------------------|
| Command     | `C <freq> <sf> <bw>\n`      |
| Parameters  | 3, space-separated           |
| Response    | `OK` or `ERR`                |

**Parameters:**

| Parameter | Type     | Description              | Example       |
|-----------|----------|--------------------------|---------------|
| `freq`    | uint32   | Frequency in Hz          | `434000000`   |
| `sf`      | uint8    | Spreading factor enum    | `9`           |
| `bw`      | uint8    | Bandwidth enum           | `4`           |

**Example — return to discovery channel:**
```
TX: C 434000000 9 4
RX: OK
```

---

### 2.9 `SET` / `GET` — Configuration Settings

Read and write persistent device settings.

**SET:**

| Field       | Value                        |
|-------------|------------------------------|
| Command     | `SET <label> <value>\n`      |
| Parameters  | 2                            |
| Response    | `OK` or `ERR`                |

**GET:**

| Field       | Value                |
|-------------|----------------------|
| Command     | `GET <label>\n`      |
| Parameters  | 1                    |
| Response    | Numeric value or `ERR` |

**Available settings labels:**

| Label | Setting         | Default Value     | Notes                            |
|-------|-----------------|-------------------|----------------------------------|
| `f`   | Frequency       | `434000000`       | Hz                               |
| `s`   | Spreading Factor| `9` (LORA_SF9)    | See §4                           |
| `b`   | Bandwidth       | `4` (LORA_BW_125) | See §4                           |
| `c`   | Coding Rate     | `1` (CR 4/5)      | See §4                           |
| `d`   | TX Power        | `22` (22 dBm)     | See §4                           |
| `o`   | Over-current    | `150`             | mA                               |
| `p`   | Preamble Length | `8`               | Symbols                          |
| `m`   | Mode            | `1` (Tracker)     | 1=Tracker, 2=Ground Station      |

**Example:**
```
TX: GET f
RX: 434000000

TX: SET f 434500000
RX: OK
```

---

### 2.10 `REBOOT` — Reboot Device

| Field     | Value        |
|-----------|--------------|
| Command   | `REBOOT\n`   |
| Parameters | None        |
| Response  | None (device resets immediately) |

---

### 2.11 `FACTORY` — Factory Reset

Resets all settings to factory defaults, erases flash, and reboots.

| Field     | Value        |
|-----------|--------------|
| Command   | `FACTORY\n`  |
| Parameters | None        |
| Response  | `OK` then device resets |

---

### 2.12 `I` / `i` — Interactive Mode On/Off (Debug Only)

Enables or disables interactive (human-friendly) mode. **Not intended for use by PC applications.**

When interactive mode is enabled:
- A `\n> ` prompt is printed after each command completes.
- Typed characters are echoed back.
- Unrecognised commands produce a `Command not recognised.` message.

When disabled (the default), **none of these are sent** — only the explicit command response data is output.

| Command | Effect                    |
|---------|---------------------------|
| `I\n`   | Enable interactive mode   |
| `i\n`   | Disable interactive mode  |

---

## 3. LoRa Over-the-Air Message Format

All structured LoRa messages follow this format:

```
[0..7]   Sender UID (8 hex chars)
[8]      Space ' '
[9]      '&' (command marker)
[10..17] Destination UID (8 hex chars, or "ffffffff" for broadcast)
[18]     Command character (single letter)
[19..]   Optional payload (variable length)
```

**Total minimum length:** 19 characters.

### 3.1 Command Characters

| Char | Name       | Direction         | Payload                         | Description                       |
|------|------------|-------------------|---------------------------------|-----------------------------------|
| `U`  | UID Query  | GS → Broadcast   | None                            | Request all trackers to identify  |
| `U`  | UID Reply  | Tracker → GS      | Own UID (8 hex chars)           | Reply to UID query                |
| `T`  | Pair/Track | GS → Tracker      | `<freq>,<sf>,<bw>` (optional)   | Command tracker to switch config  |
| `T`  | Pair ACK   | Tracker → GS      | `ACK`                           | Acknowledges pair command         |
| `V`  | Voltage Q  | GS → Tracker      | None                            | Request battery voltage           |
| `V`  | Voltage R  | Tracker → GS      | Voltage in mV (decimal string)  | Battery voltage response          |

### 3.2 Non-Command Messages

GPS tracking data is sent as raw text (not prefixed with `&`). The Ground Station appends RSSI to the message before storing it for readback via `R`.

**Format on air:**
```
<tracker_uid> <NMEA_sentence>
```

**As stored by Ground Station (readable via `R`):**
```
<tracker_uid> <NMEA_sentence> <rssi>
```

---

## 4. LoRa Parameter Reference

### Spreading Factor Values

| Value | Enum Constant | Meaning   |
|-------|---------------|-----------|
| `5`   | `LORA_SF5`    | SF5       |
| `6`   | `LORA_SF6`    | SF6       |
| `7`   | `LORA_SF7`    | SF7       |
| `8`   | `LORA_SF8`    | SF8       |
| `9`   | `LORA_SF9`    | SF9 (default) |
| `10`  | `LORA_SF10`   | SF10      |
| `11`  | `LORA_SF11`   | SF11      |
| `12`  | `LORA_SF12`   | SF12      |

### Bandwidth Values

| Value  | Enum Constant | Meaning      |
|--------|---------------|--------------|
| `0x00` | `LORA_BW_7`   | 7.8 kHz      |
| `0x01` | `LORA_BW_15`  | 15.6 kHz     |
| `0x02` | `LORA_BW_31`  | 31.25 kHz    |
| `0x03` | `LORA_BW_62`  | 62.5 kHz     |
| `0x04` | `LORA_BW_125` | 125 kHz (default) |
| `0x05` | `LORA_BW_250` | 250 kHz      |
| `0x06` | `LORA_BW_500` | 500 kHz      |

### Coding Rate Values

| Value | Enum Constant | Meaning  |
|-------|---------------|----------|
| `1`   | `LORA_CR_4_5` | 4/5 (default) |
| `2`   | `LORA_CR_4_6` | 4/6      |
| `3`   | `LORA_CR_4_7` | 4/7      |
| `4`   | `LORA_CR_4_8` | 4/8      |

### TX Power Values

Integer dBm from `-9` to `22`. Default is `22` (22 dBm).

---

## 5. Default Discovery Channel

All devices boot with these default LoRa parameters (the "discovery channel"):

| Parameter        | Value         |
|------------------|---------------|
| Frequency        | 434,000,000 Hz (434 MHz) |
| Spreading Factor | 9 (SF9)       |
| Bandwidth        | 4 (125 kHz)   |
| Coding Rate      | 1 (4/5)       |
| TX Power         | 22 dBm        |
| Preamble         | 8 symbols     |

---

## 6. Complete Workflow — Discovery to Tracking

Below is the full step-by-step sequence for discovering trackers and pairing with one.

### Step 1: Connect

Open the USB CDC serial port. No baud rate configuration is needed (USB CDC is rate-agnostic).

### Step 2: Verify Connection

```
TX: UID\n
RX: 1a2b3c4d
```

Record the Ground Station UID. The device is in Ground Station mode.

### Step 3: Ensure Discovery Channel

Optionally reset to the default discovery channel:
```
TX: C 434000000 9 4\n
RX: OK
```

### Step 4: Initiate Discovery Scan

```
TX: SCAN\n
RX: OK
```

This broadcasts a UID request. Remote trackers will respond within 0–5 seconds using random time slots.

### Step 5: Poll for Discovery Results

Wait at least 1 second, then poll:

```
TX: D\n
RX: WAIT 1          ← still in progress, 1 device found so far
```

Continue polling every 1–2 seconds:

```
TX: D\n
RX: 2 a1b2c3d4,-72 e5f6a7b8,-91
```

The response format is `<count> <uid1>,<rssi1> <uid2>,<rssi2> ...`

Parse the results. Present the list to the user for selection.

### Step 6: Pair with Selected Tracker

Choose a dedicated tracking channel (different from the discovery channel). For example:
- Frequency: `434500000` (434.5 MHz)
- SF: `9`
- BW: `4` (125 kHz)

```
TX: PAIR a1b2c3d4 434500000 9 4\n
RX: OK
```

### Step 7: Wait for Channel Switch

The pairing handshake happens automatically over the air:
1. GS sends: `<gs_uid> &a1b2c3d4T434500000,9,4`
2. Tracker ACKs: `<tracker_uid> &<gs_uid>TACK`
3. Tracker switches to 434.5 MHz and enters tracker mode.
4. GS receives ACK, switches to 434.5 MHz, enters receive mode.

You can confirm the ACK was received by reading:
```
TX: R\n
RX: a1b2c3d4 &1a2b3c4dTACK
```

If `R` returns the ACK message, the channel switch was successful. If after ~3 seconds no ACK appears, the pairing may have failed — retry the PAIR command.

### Step 8: Receive Tracking Data

Once paired, the tracker transmits GPS NMEA sentences periodically (approximately every other GPS fix, ~2 seconds). Poll `R` to read the latest:

```
TX: R\n
RX: a1b2c3d4 $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,47.0,M,,*47 -72
```

Parse the NMEA sentence for position data. The trailing integer is the RSSI in dBm.

**Note:** `R` returns the last received message. If no new message has arrived since the last read, you will get the same message again. The application should compare consecutive reads to detect new data (e.g., by timestamp in the NMEA sentence or by tracking message identity).

### Step 9: Return to Discovery Channel (Optional)

To unpair and scan for other trackers:

```
TX: C 434000000 9 4\n
RX: OK
```

This switches the Ground Station back to the discovery channel. The remote tracker will continue transmitting on the tracking channel until it is rebooted or otherwise commanded.

---

## 7. Additional Commands

### Request Voltage from a Tracker

After discovery (before pairing — on the discovery channel), you can query a tracker's battery voltage:

```
TX: T &a1b2c3d4V\n
RX: OK
```

Wait ~1–5 seconds for the response (random slot delay), then read:

```
TX: R\n
RX: a1b2c3d4 &1a2b3c4dV3850
```

The payload after `V` is the battery voltage in millivolts (e.g. `3850` = 3.85 V).

---

## 8. Error Handling

| Response | Meaning                                           |
|----------|---------------------------------------------------|
| `OK`     | Command accepted and executed/queued               |
| `ERR`    | Invalid or missing parameters                      |
| `NAK`    | Received over LoRa — unrecognised command character |
| `NONE`   | No discovery results available (no scan performed) |

### Common Failure Modes

| Scenario                          | Symptom                        | Recovery                                         |
|-----------------------------------|--------------------------------|--------------------------------------------------|
| PAIR timeout (no ACK)             | `R` never shows `TACK`         | Re-send `PAIR` or `SCAN` again                   |
| Tracker out of range              | Not in `D` results             | Move closer, increase TX power, re-scan           |
| Ground Station on wrong channel   | No responses to SCAN           | `C 434000000 9 4` to reset to discovery channel   |
| USB buffer stale data             | `R` returns old message        | Compare timestamps in NMEA data                   |

---

## 9. Timing Reference

| Event                            | Duration / Timeout    |
|----------------------------------|-----------------------|
| LoRa RX timeout                  | 5,000 ms              |
| Discovery window                 | 6,000 ms              |
| Random response slot range       | 0–5,000 ms            |
| Slot interval                    | 500 ms                |
| GPS TX interval (tracker mode)   | ~2 seconds (every other fix) |
| LoRa TX timeout                  | 1,500 ms              |
