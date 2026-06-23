/**
 * @description Generates a short, friendly AI summary of a decoded SA ID + its birth-year holidays
 *   via the DeepSeek chat API (OpenAI-compatible). Endpoint = Named Credential; key = Custom Metadata.
 *   CloudSmiths assignment - AI enhancement.
 */
public with sharing class clsPRJCSAiService {
    @AuraEnabled
    public static String getSummary(String idNumber, String holidayNames) {
        clsPRJCSSAIdDecoder.DecodedId d = clsPRJCSSAIdDecoder.decode(idNumber);
        if (d == null || !d.isValid) {
            throw new AuraHandledException('A valid South African ID number is required.');
        }
        cmtPRJCSCalendarificSetting__mdt cfg = cmtPRJCSCalendarificSetting__mdt.getInstance('Default');
        if (cfg == null || String.isBlank(cfg.fldPRJCSDeepSeekKey__c)) {
            throw new AuraHandledException('AI is not configured yet (DeepSeek key missing).');
        }
        String model = String.isBlank(cfg.fldPRJCSDeepSeekModel__c) ? 'deepseek-chat' : cfg.fldPRJCSDeepSeekModel__c;
        String prompt =
            'In 2-3 warm, friendly sentences, summarise this person for a public holiday app. ' +
            'Born ' + d.dateOfBirth.format() + ', ' + d.gender + ', ' +
            (d.isSaCitizen ? 'South African citizen' : 'permanent resident') + '. ' +
            'Public/banking holidays in their birth year ' + d.birthYear + ': ' +
            (String.isBlank(holidayNames) ? 'not available' : holidayNames) + '. ' +
            'Mention something interesting about a holiday near their birthday. Do not repeat the ID number.';

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
