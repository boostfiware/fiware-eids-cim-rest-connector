import ballerina/log;
import ballerina/http;

function removeFwdHeader(http:Request req, string additionalHeaderKey, string additionalHeaderValue) returns http:Request {

    req.removeHeader("fwd-providerurl");
    req.removeHeader("fwd-messagetype");
    req.removeHeader("fwd-logprocessnotesJN");

    if (additionalHeaderKey !== "noAdditionalHeaderKey") {    

        req.removeHeader("fwd-additionalheaderkey");

    }

    if (additionalHeaderValue !== "noAdditionalHeaderValue") {    

        req.removeHeader("fwd-additionalheadervalue");

    }

    log:printDebug("Success: Removing Forwarding Header");

    return req;

}


function extractFwdRequestHeader(http:Request req, string[] allowedRequestMessageTypeList, int rootPathLength, function (boolean, string) closureProgressError) returns @tainted [string, string, string, string, string, string, string, string]{

    // Extracting the userPath incl. query parameters after the connector foward-xx-root path-segment
    string userPath = req.rawPath.substring(rootPathLength);
    log:printDebug("Success: Extracting userPath and query parameters: " + userPath);
 
    // Extracting Fwd input parameters from request headers
    string? rHProviderUrl = req.getHeader("fwd-providerurl");
    var provider_url = rHProviderUrl is string ? rHProviderUrl : "noProviderUrlRH";

    string? rHMessageType = req.getHeader("fwd-messagetype");
    var requestMessageType = rHMessageType is string ? rHMessageType : "noMessageTypeRH";

    // Checking the given mandatory request header conditions
    if (provider_url == "noProviderUrlRH" || requestMessageType == "noMessageTypeRH" ||  allowedRequestMessageTypeList.indexOf(requestMessageType) is ()) {

        setErrorProgresstrackingLog("Error: Processing header 'providerurl' AND 'messagetype' AND valid RequestMessageTypes failed, at least one is incorrect", "extractFwdRequestHeader", closureProgressError);

    } 

    string? rHLogProcessNotesJN = req.getHeader("fwd-logprocessnotesJN");
    var logProcessNotesJNQP = rHLogProcessNotesJN == "J" ? "J" : "N";

    // Check additionalHeader with key and value, only for composing an additional Header for the final endpoint, like i.e. Authorization
    var additionalHeaderKey = "";
    var additionalHeaderValue = "";
    if (req.hasHeader("fwd-additionalheaderkey") && req.hasHeader("fwd-additionalheadervalue")) {

        string? rHAdditionalHeaderKey = req.getHeader("fwd-additionalheaderkey");
        additionalHeaderKey = rHAdditionalHeaderKey is string ? rHAdditionalHeaderKey : "noAdditionalHeaderKey";

        string? rHAdditionalHeaderValue = req.getHeader("fwd-additionalheadervalue");
        additionalHeaderValue = rHAdditionalHeaderValue is string ? rHAdditionalHeaderValue : "noAdditionalHeaderValue";

    }

    // Check Fiware-Service and Fiware-ServicePath to let them be passed if available
    var fiwareService = "";
    if (req.hasHeader("Fiware-Service")) {
    
        string? rHFiwareService = req.getHeader("Fiware-Service");
        fiwareService = rHFiwareService is string ? rHFiwareService : "noFiwareServiceRH";

    }

    var fiwareServicePath = "";
    if (req.hasHeader("Fiware-ServicePath")) {
    
        string? rHFiwareServicePath = req.getHeader("Fiware-ServicePath");
        fiwareServicePath = rHFiwareServicePath is string ? rHFiwareServicePath : "noFiwareServiceRH";

    }

    return [provider_url, userPath, requestMessageType, logProcessNotesJNQP, additionalHeaderKey, additionalHeaderValue, fiwareService, fiwareServicePath];

}


function createFwdSHIDSRequestSplitHeaderLogProcessNoteMessage(string logProcessNotesJNQP, string provider_url, string path, string messageUUID, string messageTime, string locDatTokenJWT, string additionalHeaderKey, string additionalHeaderValue) returns string {  

    // Creating the LogProcessNoteMessage for SplitHeader messages
    var addedIDSRequestSplitHeaderLogProcessNoteMessage = "";

    if (logProcessNotesJNQP == "J") {

        addedIDSRequestSplitHeaderLogProcessNoteMessage =                 
            "A SplitHeader message was sent to provider at: " + provider_url + path + "---"
            + "The following forwarding headers were removed: " + "---"
            + "fwd-providerurl, fwd-messagetype, fwd-logprocessnotesJN, fwd-additionalheaderkey, fwd-additionalheaderkey ---xxx---"
            + "The following SplitHeader headers were added to your original HTTP call" + "---"
            + "IDS-Messagetype: ids:RequestMessage ---"
            + "IDS-Id: http://industrialdataspace.org/RequestMessage/" + messageUUID + " ---"
            + "IDS-Issued: " + messageTime + " ---"
            + "IDS-ModelVersion: " + gloIDSInfoModelVersionOutgoing + " ---"
            + "IDS-IssuerConnector: https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath + " ---"
            + "IDS-SecurityToken-Type: ids:DynamicAttributeToken" + " ---"
            + "IDS-SecurityToken-TokenFormat: https://w3id.org/idsa/code/tokenformat/JWT" + " ---"
            + "IDS-SecurityToken-TokenValue: " + locDatTokenJWT + " ---"
            + "IDS-CorrelationMessage: https://www.notimplementedyet.com" + " ---"
            + "IDS-TransferContract: https://www.notimplementedyet.com" + " ---xxx---";

        if (additionalHeaderKey !== "" && additionalHeaderValue !== "") {    

            addedIDSRequestSplitHeaderLogProcessNoteMessage = addedIDSRequestSplitHeaderLogProcessNoteMessage + "An AdditionalHeader was also placed with Key: " + additionalHeaderKey + " and Value: " + additionalHeaderValue + "---END---";

        }
    }

    log:printDebug("Success: Generating SH LogProcessNoteMessage");

    return addedIDSRequestSplitHeaderLogProcessNoteMessage;

}


function createFwdHOIDSRequestHeaderOnlyLogProcessNoteMessage(string logProcessNotesJNQP, string provider_url, string path, string idsHeaderBase64UrlEncoded, string additionalHeaderKey, string additionalHeaderValue) returns string {  

    // Creating the LogProcessNoteMessage for HeaderOnly messages
    var addedIDSRequestHeaderOnlyLogProcessNoteMessage = "";

    if (logProcessNotesJNQP == "J") {

        addedIDSRequestHeaderOnlyLogProcessNoteMessage =                 
            "A HeaderOnly message was sent to provider at: " + provider_url + path + " ---"
            + "The following forwarding headers were removed: " + " ---"
            + "fwd-providerurl, fwd-messagetype, fwd-logprocessnotesJN, fwd-additionalheaderkey, fwd-additionalheaderkey ---"
            + "The following HeaderOnly header was added to your original HTTP call: " + " ---"
            + "header: " + idsHeaderBase64UrlEncoded + " ---xxx---";

        if (additionalHeaderKey !== "noAdditionalHeaderKey" && additionalHeaderValue !== "noAdditionalHeaderValue") {    

            addedIDSRequestHeaderOnlyLogProcessNoteMessage = addedIDSRequestHeaderOnlyLogProcessNoteMessage + "An AdditionalHeader was also placed with Key: " + additionalHeaderKey + " and Value: " + additionalHeaderValue + "---END---";

        }
    }
    
    log:printDebug("Success: Generating HO LogProcessNoteMessage");

    return addedIDSRequestHeaderOnlyLogProcessNoteMessage;
    
}