/**
 * @description Retrieves public / banking holidays for a given year from the Calendarific API.
 *   The endpoint and API key are read from a Named Credential (ncdPRJCSCalendarific) and the
 *   cmtPRJCSCalendarificSetting__mdt metadata, so no secrets or URLs are hardcoded in Apex.
 *   CloudSmiths assignment - User Story 4.
 */
public with sharing class clsPRJCSCalendarificService {
    private static final String SETTING_DEVELOPER_NAME = 'Default';
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;

    /**
     * @description Raised when configuration is missing or the holiday service returns an error.
     */
    public class CalendarificException extends Exception {}

    /**
     * @description A single holiday returned to the LWC.
     */
    public class Holiday {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String holidayDate; // ISO date string (yyyy-MM-dd)
        @AuraEnabled public String holidayType;
    }

    /**
     * @description Calls the Calendarific holiday API for the supplied year and configured country.
     * @param year the 4-digit year derived from the SA ID date of birth
     * @return list of holidays (possibly empty)
     */
    public static List<Holiday> getHolidays(Integer year) {
        if (year == null) {
            throw new CalendarificException('A year is required to retrieve holidays.');
        }
        cmtPRJCSCalendarificSetting__mdt config = getConfig();

        String endpoint = 'callout:' + config.fldPRJCSNamedCredential__c +
            '/api/' + config.fldPRJCSApiVersion__c + '/holidays' +
            '?api_key=' + EncodingUtil.urlEncode(config.fldPRJCSApiKey__c, 'UTF-8') +
            '&country=' + EncodingUtil.urlEncode(config.fldPRJCSCountryCode__c, 'UTF-8') +
            '&year=' + year;
        // US4 - optionally narrow to "national" (public, federal and bank) holidays per config.
        if (String.isNotBlank(config.fldPRJCSHolidayType__c)) {
            endpoint += '&type=' + EncodingUtil.urlEncode(config.fldPRJCSHolidayType__c, 'UTF-8');
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(CALLOUT_TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() != 200) {
            throw new CalendarificException(
                'The holiday service returned HTTP ' + response.getStatusCode() +
                ' (' + response.getStatus() + ').'
            );
        }
        return parseHolidays(response.getBody());
    }

    /**
     * @description Reads the integration configuration from Custom Metadata.
     * @return the Default Calendarific setting record
     */
    @TestVisible
    private static cmtPRJCSCalendarificSetting__mdt getConfig() {
        cmtPRJCSCalendarificSetting__mdt config =
            cmtPRJCSCalendarificSetting__mdt.getInstance(SETTING_DEVELOPER_NAME);
        if (config == null ||
            String.isBlank(config.fldPRJCSNamedCredential__c) ||
            String.isBlank(config.fldPRJCSApiVersion__c) ||
            String.isBlank(config.fldPRJCSCountryCode__c)) {
            throw new CalendarificException(
                'Calendarific configuration is missing. Please populate the "' +
                SETTING_DEVELOPER_NAME + '" Calendarific Setting metadata record.'
            );
        }
        return config;
    }

    /**
     * @description Defensively parses the Calendarific JSON response into Holiday DTOs.
     * @param body the raw response body
     * @return list of holidays (possibly empty)
     */
    @TestVisible
    private static List<Holiday> parseHolidays(String body) {
        List<Holiday> holidays = new List<Holiday>();
        if (String.isBlank(body)) {
            return holidays;
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        Object responseObj = root.get('response');
        if (!(responseObj instanceof Map<String, Object>)) {
            return holidays;
        }
        Object holidaysObj = ((Map<String, Object>) responseObj).get('holidays');
        if (!(holidaysObj instanceof List<Object>)) {
            return holidays;
        }
        for (Object item : (List<Object>) holidaysObj) {
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> raw = (Map<String, Object>) item;
            Holiday holiday = new Holiday();
            holiday.name = (String) raw.get('name');
            holiday.description = (String) raw.get('description');

            Object dateObj = raw.get('date');
            if (dateObj instanceof Map<String, Object>) {
                holiday.holidayDate = (String) ((Map<String, Object>) dateObj).get('iso');
            }
            Object typeObj = raw.get('type');
            if (typeObj instanceof List<Object>) {
                List<String> types = new List<String>();
                for (Object type : (List<Object>) typeObj) {
                    types.add(String.valueOf(type));
                }
                holiday.holidayType = String.join(types, ', ');
            }
            holidays.add(holiday);
        }
        return holidays;
    }
}
