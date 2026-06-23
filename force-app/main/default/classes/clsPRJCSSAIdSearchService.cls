/**
 * @description Persists valid SA ID searches and maintains the per-ID search counter (User Story 3).
 *
 *   Declared `without sharing` INTENTIONALLY: on a public Experience Cloud site every visitor runs as
 *   the single guest user, and the per-ID counter record must be read and updated across visits
 *   regardless of record sharing. Object- and field-level security are still enforced explicitly
 *   (CRUD check + WITH SECURITY_ENFORCED + Security.stripInaccessible) so the elevated sharing
 *   context cannot be abused.
 */
public without sharing class clsPRJCSSAIdSearchService {
    /**
     * @description Raised when the running user lacks the required object/field permissions.
     */
    public class SecurityException extends Exception {}

    /**
     * @description Upserts the search record for a decoded ID and increments its counter.
     * @param decoded the validated/decoded ID (must be valid)
     * @return the persisted record (with Id and the updated fldPRJCSSearchCount__c)
     */
    public static objPRJCSSAIdSearch__c recordSearch(clsPRJCSSAIdDecoder.DecodedId decoded) {
        if (decoded == null || !decoded.isValid) {
            throw new SecurityException('Only valid ID numbers can be recorded.');
        }
        assertCrudAccess();

        // Look up any existing record for this ID (field-level security enforced on the query).
        List<objPRJCSSAIdSearch__c> existing = [
            SELECT Id, fldPRJCSSearchCount__c
            FROM objPRJCSSAIdSearch__c
            WHERE fldPRJCSIdNumber__c = :decoded.idNumber
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        objPRJCSSAIdSearch__c record = existing.isEmpty()
            ? new objPRJCSSAIdSearch__c()
            : existing[0];

        Decimal currentCount = (record.fldPRJCSSearchCount__c == null)
            ? 0
            : record.fldPRJCSSearchCount__c;

        record.fldPRJCSIdNumber__c = decoded.idNumber;
        record.fldPRJCSDateOfBirth__c = decoded.dateOfBirth;
        record.fldPRJCSGender__c = decoded.gender;
        record.fldPRJCSSaCitizen__c = decoded.isSaCitizen;
        record.fldPRJCSHolidayYear__c = decoded.birthYear;
        record.fldPRJCSLastSearchedDate__c = System.now();
        record.fldPRJCSSearchCount__c = currentCount + 1;

        // Enforce field-level security on write, then persist.
        SObjectAccessDecision decision = Security.stripInaccessible(
            AccessType.UPSERTABLE,
            new List<objPRJCSSAIdSearch__c>{ record }
        );
        objPRJCSSAIdSearch__c sanitized = (objPRJCSSAIdSearch__c) decision.getRecords()[0];
        upsert sanitized;
        return sanitized;
    }

    /**
     * @description Verifies the running user can create and update the search object.
     */
    @TestVisible
    private static void assertCrudAccess() {
        DescribeSObjectResult describe = objPRJCSSAIdSearch__c.SObjectType.getDescribe();
        if (!describe.isCreateable() || !describe.isUpdateable()) {
            throw new SecurityException(
                'You do not have permission to record ID number searches.'
            );
        }
    }
}
