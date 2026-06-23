/**
 * @description Reusable HttpCalloutMock for Calendarific tests. Returns a configurable
 *   status code and body, plus a canned success payload. CloudSmiths assignment - User Story 4.
 */
@IsTest
public class tstPRJCSCalendarificMock implements HttpCalloutMock {
    private final Integer statusCode;
    private final String body;

    public tstPRJCSCalendarificMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
    }

    public HttpResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        response.setStatusCode(this.statusCode);
        response.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
        response.setBody(this.body);
        return response;
    }

    /**
     * @description Canned, valid Calendarific response with three South African holidays.
     */
    public static String sampleHolidaysJson() {
        return '{"meta":{"code":200},"response":{"holidays":[' +
            '{"name":"New Year\'s Day","description":"New Year\'s Day is the first day of the year.","date":{"iso":"1980-01-01"},"type":["National holiday"]},' +
            '{"name":"Workers\' Day","description":"Workers Day in South Africa.","date":{"iso":"1980-05-01"},"type":["National holiday"]},' +
            '{"name":"Day of Goodwill","description":"Day of Goodwill.","date":{"iso":"1980-12-26"},"type":["National holiday","Observance"]}' +
            ']}}';
    }
}
