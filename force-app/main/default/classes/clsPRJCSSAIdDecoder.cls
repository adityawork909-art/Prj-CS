/**
 * @description Validates and decodes a South African ID number.
 *   Format (13 digits): YYMMDD SSSS C A Z
 *     - YYMMDD : date of birth
 *     - SSSS   : gender (0000-4999 = Female, 5000-9999 = Male)
 *     - C      : citizenship (0 = SA citizen, 1 = permanent resident)
 *     - A      : historically race, now unused
 *     - Z      : Luhn (mod 10) checksum digit
 *   Pure logic only (no DML / SOQL) so the rules are fully unit-testable in isolation.
 *   CloudSmiths assignment - User Story 2.
 */
public with sharing class clsPRJCSSAIdDecoder {
    private static final Integer ID_LENGTH = 13;

    /**
     * @description Result of decoding an SA ID number. Returned to the LWC via the controller.
     */
    public class DecodedId {
        @AuraEnabled public Boolean isValid = false;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String gender;
        @AuraEnabled public Boolean isSaCitizen = false;
        @AuraEnabled public Integer birthYear;
    }

    /**
     * @description Validates and decodes the supplied ID number.
     * @param rawId the raw user input
     * @return DecodedId with isValid=true + decoded values, or isValid=false + errorMessage
     */
    public static DecodedId decode(String rawId) {
        DecodedId result = new DecodedId();
        String idNumber = String.isBlank(rawId) ? '' : rawId.trim();
        result.idNumber = idNumber;

        if (String.isBlank(idNumber)) {
            result.errorMessage = 'Please enter a South African ID number.';
            return result;
        }
        if (idNumber.length() != ID_LENGTH || !idNumber.isNumeric()) {
            result.errorMessage = 'A South African ID number must be exactly 13 digits.';
            return result;
        }

        Date dob = parseDateOfBirth(idNumber);
        if (dob == null) {
            result.errorMessage = 'The ID number does not contain a valid date of birth.';
            return result;
        }

        Integer citizenDigit = Integer.valueOf(idNumber.substring(10, 11));
        if (citizenDigit != 0 && citizenDigit != 1) {
            result.errorMessage = 'The ID number contains an invalid citizenship classification.';
            return result;
        }

        if (!isLuhnValid(idNumber)) {
            result.errorMessage = 'The ID number failed the checksum (Luhn) validation.';
            return result;
        }

        // All checks passed - decode the parts.
        result.isValid = true;
        result.dateOfBirth = dob;
        result.birthYear = dob.year();
        Integer genderDigits = Integer.valueOf(idNumber.substring(6, 10));
        result.gender = (genderDigits < 5000) ? 'Female' : 'Male';
        result.isSaCitizen = (citizenDigit == 0);
        return result;
    }

    /**
     * @description Parses YYMMDD into a Date, resolving the century and rejecting impossible dates.
     * @param idNumber the validated 13-digit string
     * @return the Date of birth, or null if the date portion is invalid
     */
    @TestVisible
    private static Date parseDateOfBirth(String idNumber) {
        try {
            Integer yy = Integer.valueOf(idNumber.substring(0, 2));
            Integer mm = Integer.valueOf(idNumber.substring(2, 4));
            Integer dd = Integer.valueOf(idNumber.substring(4, 6));

            if (mm < 1 || mm > 12 || dd < 1) {
                return null;
            }
            // Resolve century: assume the current century unless that yields a future date.
            Integer currentYy = Math.mod(Date.today().year(), 100);
            Integer century = (yy <= currentYy) ? 2000 : 1900;
            Integer fullYear = century + yy;

            if (dd > Date.daysInMonth(fullYear, mm)) {
                return null;
            }
            Date candidate = Date.newInstance(fullYear, mm, dd);
            if (candidate > Date.today()) {
                return null;
            }
            return candidate;
        } catch (Exception ex) {
            return null;
        }
    }

    /**
     * @description Standard Luhn (mod 10) checksum validation across all 13 digits.
     * @param idNumber the validated 13-digit string
     * @return true when the checksum is valid
     */
    @TestVisible
    private static Boolean isLuhnValid(String idNumber) {
        Integer sum = 0;
        Boolean alternate = false;
        for (Integer i = idNumber.length() - 1; i >= 0; i--) {
            Integer digit = Integer.valueOf(idNumber.substring(i, i + 1));
            if (alternate) {
                digit *= 2;
                if (digit > 9) {
                    digit -= 9;
                }
            }
            sum += digit;
            alternate = !alternate;
        }
        return Math.mod(sum, 10) == 0;
    }
}
