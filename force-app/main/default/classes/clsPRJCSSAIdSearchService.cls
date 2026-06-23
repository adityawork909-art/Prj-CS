/**
 * @description Persists valid SA ID searches and maintains the per-ID search counter (User Story 3).
 *
 *   Declared `without sharing` INTENTIONALLY: on a public Experience Cloud site every visitor runs as
 *   the single guest user, and the per-ID counter record must be read and updated across visits
 *   regardless of record sharing. A guest user's license CANNOT be granted the "Edit" object
 *   permission, yet US3 requires incrementing an existing record - so the counter upsert runs in
 *   system mode (Apex bypasses object CRUD for DML). Create + read access is still checked and
 *   read-level security is enforced (WITH SECURITY_ENFORCED). The input is pre-validated and the
 *   class performs a single, well-scoped upsert, so the elevated context cannot be abused.
 */
public without sharing class clsPRJCSSAIdSearchService {
    /**
     * @description Raised when the running user lacks the required object permissions.
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

        // Look up any existing record for this ID (read-level security enforced on the query).
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

        // System-mode upsert by design (see class header): the public-site guest user cannot hold the
        // "Edit" object permission, yet the counter must increment on repeat searches. Only this
        // object's pre-validated, decoded fields are written.
        upsert record;
        return record;
    }

    /**
     * @description Verifies the running user can create and read the search object. The counter
     *   update itself runs in system mode (guest licenses cannot hold "Edit"), so update access is
     *   intentionally not required here.
     */
    @TestVisible
    private static void assertCrudAccess() {
        DescribeSObjectResult describe = objPRJCSSAIdSearch__c.SObjectType.getDescribe();
        if (!describe.isCreateable() || !describe.isAccessible()) {
            throw new SecurityException(
                'You do not have permission to record ID number searches.'
            );
        }
    }
}
