## ADDED Requirements

### Requirement: Display rolling usage percentage
The plugin SHALL display the 5-hour rolling window usage as a percentage, representing the current consumption within the $12 usage limit.

#### Scenario: Fetch usage successfully
- **WHEN** plugin fetches the dashboard with valid workspace ID and auth cookie
- **THEN** it SHALL return the rolling usage percentage (0-100)

#### Scenario: Usage unavailable
- **WHEN** the dashboard data does not contain rolling usage
- **THEN** the plugin SHALL skip the rolling item gracefully

### Requirement: Display weekly usage percentage
The plugin SHALL display the weekly window usage as a percentage, representing the current consumption within the $30 usage limit.

#### Scenario: Fetch weekly usage successfully
- **WHEN** plugin fetches the dashboard with valid credentials
- **THEN** it SHALL return the weekly usage percentage (0-100)

#### Scenario: Weekly usage not present
- **WHEN** the dashboard data does not contain weekly usage
- **THEN** the plugin SHALL skip the weekly item

### Requirement: Display monthly usage percentage
The plugin SHALL display the monthly window usage as a percentage, representing the current consumption within the $60 usage limit.

#### Scenario: Fetch monthly usage successfully
- **WHEN** plugin fetches the dashboard with valid credentials
- **THEN** it SHALL return the monthly usage percentage (0-100)

#### Scenario: Monthly usage not present
- **WHEN** the dashboard data does not contain monthly usage
- **THEN** the plugin SHALL skip the monthly item

### Requirement: Show reset times
Each usage item SHALL display the time until the usage window resets.

#### Scenario: Reset time available
- **WHEN** dashboard data includes resetInSec for a usage window
- **THEN** the item SHALL include a resetAt field with ISO 8601 timestamp

#### Scenario: Reset time is zero or negative
- **WHEN** resetInSec is 0 or negative
- **THEN** the resetAt field SHALL be null

### Requirement: Color-code usage status
Each usage item SHALL use color (red/orange/yellow/blue) and status (critical/warning/normal) based on usage percentage thresholds.

#### Scenario: Usage is critical
- **WHEN** usage percentage >= 90%
- **THEN** color SHALL be "red" and status SHALL be "critical"

#### Scenario: Usage is warning
- **WHEN** usage percentage >= 75% and < 90%
- **THEN** color SHALL be "orange" (>=80%) or "yellow" (>=60%) and status SHALL be "warning"

#### Scenario: Usage is normal
- **WHEN** usage percentage < 75%
- **THEN** color SHALL be "blue" and status SHALL be "normal"

### Requirement: Show plan badge
The plugin SHALL display a "Go" badge to indicate the subscription plan.

#### Scenario: Badge displayed
- **WHEN** plugin returns usage items
- **THEN** the response SHALL include `badge: "Go"`

### Requirement: Parse dashboard via SolidJS SSR hydration data
The plugin SHALL parse usage data from the OpenCode Go dashboard page using SolidJS SSR hydration output embedded in the HTML.

#### Scenario: SSR JSON.parse format
- **WHEN** the dashboard HTML contains `$R[0]=JSON.parse('...')` format
- **THEN** the plugin SHALL extract usage data from the parsed JSON

#### Scenario: SSR raw object format
- **WHEN** the dashboard HTML contains `$R[0]={...}` raw object format
- **THEN** the plugin SHALL sanitize and parse the object

#### Scenario: Per-field fallback
- **WHEN** both JSON.parse and raw object parsing fail
- **THEN** the plugin SHALL fall back to per-field regex extraction for rollingUsage, weeklyUsage, monthlyUsage

#### Scenario: All parsing fails
- **WHEN** none of the parsing strategies succeed
- **THEN** the plugin SHALL return a "dashboard parse failed" error

### Requirement: Handle expired authentication
The plugin SHALL detect expired auth cookie (HTTP 401/403) and return a user-friendly error message.

#### Scenario: Cookie expired
- **WHEN** dashboard returns HTTP 401 or 403
- **THEN** the plugin SHALL return "Auth Cookie 已过期，请重新登录" error

### Requirement: Display token usage chart (optional)
The plugin SHALL optionally build a daily token usage line chart from local OpenCode data files.

#### Scenario: Chart from local data
- **WHEN** DATA_DIR exists and contains parseable .jsonl files with token usage records
- **THEN** the plugin SHALL include a chart with daily token usage breakdowns

#### Scenario: No data directory
- **WHEN** DATA_DIR does not exist or has no parseable files
- **THEN** the chart SHALL be silently omitted

### Requirement: Support i18n
The plugin SHALL support Chinese (zh-Hans) and English (en) translations for all user-facing strings.

#### Scenario: Chinese language
- **WHEN** USAGEBOARD_LANGUAGE is "zh-Hans"
- **THEN** all text SHALL display in Chinese

#### Scenario: English language
- **WHEN** USAGEBOARD_LANGUAGE is "en" or not specified
- **THEN** all text SHALL display in English
