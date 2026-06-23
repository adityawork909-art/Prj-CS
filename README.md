# Prj-CSV2.0
## User stories → implementation

| Story | Requirement | Where it is implemented |
|-------|-------------|--------------------------|
| **US1** | Web page with an ID input, an info/description section and a Search button | `lwcPRJCSSAIdHolidayChecker` — Tab 1 (Search) |
| **US2** | Search disabled until a valid SA ID is entered (Luhn + date + citizenship); prompt on invalid | Client-side validation in the LWC (mirrors Apex) + `clsPRJCSSAIdDecoder` server-side; Tab 2 shows the decoded breakdown |
| **US3** | Store decoded info; ID number is a unique key; increment a per-ID search counter | `objPRJCSSAIdSearch__c` (unique external-ID `fldPRJCSIdNumber__c`) + `clsPRJCSSAIdSearchService` upsert/increment; Tab 3 |
| **US4** | After save, call Calendarific for the birth year and display holidays | `clsPRJCSCalendarificService` (Named Credential + `type=national`); Tab 4 |

- **Tests** — 18 tests, mock-based callouts, meaningful asserts, FLS exercised via a permission-set test user (`System.runAs`). Coverage: Decoder 95% · Callout 92% · Persistence 93% · Controller 80%.

## Deploy to an org

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias>
```

> If the `customMetadata` record gacks with `UNKNOWN_EXCEPTION` on first deploy, deploy the custom-metadata **type** first (it is under `objects/`), then the record — the type must exist before the record.

## Set the Calendarific API key (kept out of source control)

The committed record `cmtPRJCSCalendarificSetting.Default` ships with `fldPRJCSApiKey__c = REPLACE_WITH_YOUR_CALENDARIFIC_API_KEY`. After deploying, set the real key in the org:

**Setup → Custom Metadata Types → PRJCS Calendarific Setting → Manage Records → Default → Edit → API Key**, then save.

## Expose to Experience Cloud guest users

1. Create / open a **Digital Experience (Experience Cloud) site**.
2. In **Experience Builder**, drag the **PRJCS SA ID Holiday Checker** component onto a public page and publish.
3. **Workspaces → Administration → Pages → Guest user profile** (or **Settings → General → Guest user**), then assign the **`PRJCS Holiday Access`** permission set to the site's guest user (the permission set grants the Apex controller, object CRUD and field-level security).
4. Activate the site — guests can now use the page via its public URL with no login.

## Components

- **Object:** `objPRJCSSAIdSearch__c` + 7 fields (`fldPRJCSIdNumber__c`, `fldPRJCSDateOfBirth__c`, `fldPRJCSGender__c`, `fldPRJCSSaCitizen__c`, `fldPRJCSSearchCount__c`, `fldPRJCSHolidayYear__c`, `fldPRJCSLastSearchedDate__c`)
- **Config:** `ncdPRJCSCalendarific` (Named Credential), `cmtPRJCSCalendarificSetting__mdt` (+ 5 fields, + `Default` record)
- **Apex:** `clsPRJCSSAIdDecoder`, `clsPRJCSCalendarificService`, `clsPRJCSSAIdSearchService`, `clsPRJCSSAIdHolidayController`
- **Tests:** `tstPRJCSCalendarificMock`, `tstPRJCSUserFactory`, `tstPRJCSSAIdDecoder`, `tstPRJCSCalendarificService`, `tstPRJCSSAIdSearchService`, `tstPRJCSSAIdHolidayController`
- **UI:** `lwcPRJCSSAIdHolidayChecker` (4-tab LWC, exposed to community)
- **Access:** `pmsPRJCSHolidayAccess` (permission set)
