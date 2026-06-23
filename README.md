# Prj-CS — South African ID Holiday Checker

CloudSmiths Salesforce Developer Technical Assignment. A single Lightning Web Component (four tabs) that lets a visitor enter their **South African ID number** to validate it, decode it, store the search, and view the **public/banking holidays** for their year of birth. Built to be exposed to **Experience Cloud guest users** with no login.

All components follow the naming convention **`‹3-letter-type›PRJCS‹Name›`** (e.g. `objPRJCSSAIdSearch__c`, `clsPRJCSSAIdDecoder`, `lwcPRJCSSAIdHolidayChecker`) — no underscores except the platform-mandated `__c` / `__mdt` suffixes.

## User stories → implementation

| Story | Requirement | Where it is implemented |
|-------|-------------|--------------------------|
| **US1** | Web page with an ID input, an info/description section and a Search button | `lwcPRJCSSAIdHolidayChecker` — Tab 1 (Search) |
| **US2** | Search disabled until a valid SA ID is entered (Luhn + date + citizenship); prompt on invalid | Client-side validation in the LWC (mirrors Apex) + `clsPRJCSSAIdDecoder` server-side; Tab 2 shows the decoded breakdown |
| **US3** | Store decoded info; ID number is a unique key; increment a per-ID search counter | `objPRJCSSAIdSearch__c` (unique external-ID `fldPRJCSIdNumber__c`) + `clsPRJCSSAIdSearchService` upsert/increment; Tab 3 |
| **US4** | After save, call Calendarific for the birth year and display holidays | `clsPRJCSCalendarificService` (Named Credential + `type=national`); Tab 4 |

## Architecture & best practices

- **Separation of concerns** — pure decoder/validator (`clsPRJCSSAIdDecoder`), callout service (`clsPRJCSCalendarificService`), persistence (`clsPRJCSSAIdSearchService`), and a thin `@AuraEnabled` controller (`clsPRJCSSAIdHolidayController`).
- **Security (review-ready)** — controller is `with sharing`; the persistence class is `without sharing` *by design* (the public guest user must update a shared counter across visits) but still enforces **CRUD** (describe checks), **FLS on read** (`WITH SECURITY_ENFORCED`) and **FLS on write** (`Security.stripInaccessible`).
- **No hardcoded secrets / URLs** — endpoint via **Named Credential** `ncdPRJCSCalendarific`; API key + country + version + holiday type in **Custom Metadata** `cmtPRJCSCalendarificSetting__mdt`. The committed config record holds a **placeholder** key only.
- **Callout-before-DML** — the Apex callout runs before persistence to respect the platform rule that a callout cannot follow DML in the same transaction; a holiday-API failure is non-fatal (the search is still recorded and a soft warning is surfaced).
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
