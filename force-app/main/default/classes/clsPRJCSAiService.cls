/**
 * @description AI helpers (DeepSeek, OpenAI-compatible) for the SA ID Holiday Checker.
 *   Endpoint = Named Credential (ncdPRJCSDeepSeek); key/model = Custom Metadata. CloudSmiths assignment.
 */
public with sharing class clsPRJCSAiService {
    @AuraEnabled
    public static String getSummary(String idNumber, String holidayNames) {
        clsPRJCSSAIdDecoder.DecodedId d = decoded(idNumber);
        String prompt =
            'In 2-3 warm, friendly sentences summarise this person for a public holiday app. Born ' +
            d.dateOfBirth.format() + ', ' + d.gender + ', ' +
            (d.isSaCitizen ? 'South African citizen' : 'permanent resident') +
            '. Public/banking holidays in birth year ' + d.birthYear + ': ' +
            (String.isBlank(holidayNames) ? 'not available' : holidayNames) +
            '. Mention something interesting about a holiday near their birthday. Do not repeat the ID number.';
        return chat(prompt);
    }

    @AuraEnabled
    public static String explainId(String idNumber) {
        clsPRJCSSAIdDecoder.DecodedId d = decoded(idNumber);
        String prompt =
            'In 2 short, friendly sentences explain what a South African ID number reveals, using this ' +
            'decoded example: date of birth ' + d.dateOfBirth.format() + ', ' + d.gender + ', ' +
            (d.isSaCitizen ? 'South African citizen' : 'permanent resident') +
            '. Keep it simple and reassuring. Do not repeat the ID number itself.';
        return chat(prompt);
    }

    @AuraEnabled
    public static String aiAsk(String action, String idNumber, String holidayNames, String language) {
        clsPRJCSSAIdDecoder.DecodedId d = decoded(idNumber);
        String who = 'born ' + d.dateOfBirth.format() + ', ' + d.gender + ', ' +
            (d.isSaCitizen ? 'SA citizen' : 'permanent resident') + ' (birth year ' + d.birthYear + ')';
        String hol = String.isBlank(holidayNames) ? 'not available' : holidayNames;
        String p;
        if (action == 'explain') {
            p = 'In 2 short, friendly sentences explain what a South African ID reveals, using: ' + who +
                '. Simple and reassuring. Do not repeat the number.';
        } else if (action == 'longweekend') {
            Integer currentYear = Date.today().year();
            p = 'List South African public holidays in ' + currentYear + ' that fall on a Friday or Monday (or adjacent to a weekend), creating long weekends. ' +
                'Format each as a bullet: "Holiday Name (Date) – reason". Be concise, max 8 bullets.';
        } else if (action == 'funfacts') {
            p = 'Give one short fun fact (max 12 words) for up to 5 of these South African holidays: ' + hol +
                '. Format each line as "Holiday - fact".';
        } else {
            p = 'In 2-3 warm sentences summarise this person for a holiday app: ' + who + '. Holidays: ' + hol +
                '. Mention a holiday near their birthday. Do not repeat the number.';
        }
        if (String.isNotBlank(language) && language != 'English') {
            p += ' Respond entirely in ' + language + '.';
        }
        return chat(p);
    }

    private static clsPRJCSSAIdDecoder.DecodedId decoded(String idNumber) {
        clsPRJCSSAIdDecoder.DecodedId d = clsPRJCSSAIdDecoder.decode(idNumber);
        if (d == null || !d.isValid) {
            throw new AuraHandledException('A valid South African ID number is required.');
        }
        return d;
    }

    private static String chat(String prompt) {
        cmtPRJCSCalendarificSetting__mdt cfg = cmtPRJCSCalendarificSetting__mdt.getInstance('Default');
        if (cfg == null || String.isBlank(cfg.fldPRJCSDeepSeekKey__c)) {
            throw new AuraHandledException('AI is not configured yet (DeepSeek key missing).');
        }
        String model = String.isBlank(cfg.fldPRJCSDeepSeekModel__c) ? 'deepseek-chat' : cfg.fldPRJCSDeepSeekModel__c;
        Map<String, Object> body = new Map<String, Object>{
            'model' => model,
            'stream' => false,
            'max_tokens' => 220,
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
            }
        };
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ncdPRJCSDeepSeek/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + cfg.fldPRJCSDeepSeekKey__c);
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('AI service returned HTTP ' + res.getStatusCode() + '.');
        }
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        Object choicesObj = root.get('choices');
        if (!(choicesObj instanceof List<Object>) || ((List<Object>) choicesObj).isEmpty()) {
            return '';
        }
        Map<String, Object> first = (Map<String, Object>) ((List<Object>) choicesObj)[0];
        Map<String, Object> message = (Map<String, Object>) first.get('message');
        return message == null ? '' : (String) message.get('content');
    }
}
