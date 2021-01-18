import ballerina/log;
import ballerina/file;
import ballerina/http;
import ballerina/mime;


function getSelfDescriptionWithMPRequest(http:Caller caller, http:Request req) {

    // ProgressErrorTracking with closure
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };
    var closureProgress = function (boolean errorB, string errorM) {
        progress["errorBefore"] = errorB;
        progress["errorMessage"] = errorM;
    };
    
    // Extracting bodyparts from incoming MultiPart request
    json[] bodyPartJsonContentArray = [];

    var bodyParts = req.getBodyParts();

    if (bodyParts is mime:Entity[]) {

        bodyPartJsonContentArray = getMPBodyPartJsonContentArray(bodyParts, closureProgress);

    } else {

        setErrorProgresstrackingLog("Error: Extracting bodyparts from incoming MultiPart request failed, no Entity[]", "getSelfDescriptionWithMPRequest", closureProgress);

    }

    // Extracting and checking the requestMessageType from incoming MultiPart request
    map<json> incomingMultipartHeaderJsonMap = {};
    string requestMessageType = "";
    string responseMessageType = "ids:DescriptionResponseMessage";
    string rejectionMessageType = "ids:RejectionMessage";

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Extracting bodyparts from incoming MultiPart request");
        incomingMultipartHeaderJsonMap = <map<json>>bodyPartJsonContentArray[0];
        requestMessageType = incomingMultipartHeaderJsonMap["@type"].toString();

        if (requestMessageType !== "ids:DescriptionRequestMessage") {

            setErrorProgresstrackingLog("Error: Extracting and checking for ids:DescriptionRequestMessage failed, was: " + requestMessageType + ". Only ids:DescriptionRequestMessage is implmented as mandatory MessageType, this connector implements the LDP HTTP-Header solution as described in the IDSA Communication Guide (Section: 3.1.2 HTTP-Header, https://industrialdataspace.jiveon.com/docs/DOC-3062", "getSelfDescriptionWithMPRequest", closureProgress);

        } 

    } else {    

        log:printDebug("Info: Skipping extracting and checking the requestMessageType from incoming MultiPart request, error happened before");

    }

    // Validating DAT JWT
    string incomingDatToken = "";

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Extracting and checking the requestMessageType from incoming MultiPart request");
        map<json> securityTokenResult = <map<json>>incomingMultipartHeaderJsonMap["ids:securityToken"];
        incomingDatToken = securityTokenResult["ids:tokenValue"].toString();
        validateIncomingDatToken(<@untainted>incomingDatToken, closureProgress);

    } else {    

        log:printDebug("Info: Skipping validating DAT JWT, error happened before");

    }

    // Providing outgoing DAT JWT
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Validating DAT JWT");
        provideGlobalDatToken(closureProgress);

    } else {    

        log:printDebug("Info: Skipping providing outgoing DAT JWT, error happened before");

    }

    // Creating IDS header
    json idsHeader = {};
    mime:Entity multipartHeader = new;

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing outgoing DAT JWT");

        json|error? createIDSHeaderResult = createIDSHeader(responseMessageType);

        if (createIDSHeaderResult is json) {

            idsHeader = createIDSHeaderResult;
            multipartHeader = createMPHeader(idsHeader);

        } else {

            setErrorProgresstrackingLog("Error: Creating IDS header failed, no valid JSON", "getSelfDescriptionWithMPRequest", closureProgress, createIDSHeaderResult);
        }

    } else {

        log:printDebug("Info: Skipping creating IDS header, error happened before");

    }

    // Creating IDS Multipart payload with selfdescription.json
    json selfDescriptionJSON = {};
    mime:Entity multipartPayload = new;

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Creating IDS header");

        if (file:exists(gloFilePathSelfDesriptionInBallerina)) {

            json|error readSelfDesriptionResult = readFileSelfDescriptionJsonLd();

            if (readSelfDesriptionResult is json) {

                multipartPayload = createMPPayload(readSelfDesriptionResult);

            } else {

                setErrorProgresstrackingLog("Error: Creating IDS Multipart payload with selfdescription.json failed, no valid JSON", "getSelfDescriptionWithMPRequest", closureProgress, readSelfDesriptionResult);

            }
            
        } else {

            setErrorProgresstrackingLog("Error: Creating IDS Multipart payload with selfdescription.json failed, file not found/existed", "getSelfDescriptionWithMPRequest", closureProgress);

        }

    } else {

        log:printDebug("Info: Skipping creating IDS Multipart payload with selfdescription.json, error happened before");

    }

    // Responding back to caller
    http:Response res = new;

    // Preparing and sending response back to Caller
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Creating IDS Multipart payload with selfdescription.json");
        res.setBodyParts([multipartHeader, multipartPayload], contentType = mime:MULTIPART_FORM_DATA);
        res.statusCode = 200;
        log:printDebug("Info: Sending response back to caller");

    } else {

        json|error? createIDSHeaderResult = createIDSHeader(rejectionMessageType);

        if (createIDSHeaderResult is json) {

            log:printDebug("Error: Creating IDS Multipart message with selfdescription.json finally failed, preparing MultiPart error message");

            idsHeader = createIDSHeaderResult;
            multipartHeader = createMPHeader(idsHeader);
            multipartPayload = createMPPayload({"Message": progress["errorMessage"].toJsonString()});
            res.setBodyParts([multipartHeader, multipartPayload], contentType = mime:MULTIPART_FORM_DATA);
            res.statusCode = 500;

        } else {

            res.setPayload("Message: " + progress["errorMessage"].toJsonString());
            res.statusCode = 500;

        }
    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "getSelfDescriptionWithMPRequest", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}


function getSelfDescription(http:Caller caller, http:Request req) {

    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;

    if (file:exists(gloFilePathSelfDesriptionInBallerina)) {

        res.statusCode = 200;
        res.setFileAsPayload(gloFilePathSelfDesriptionInBallerina, contentType = "application/ld+json");

        log:printDebug("Success: Reading selfdescription.json");

    } else {

        progress["errorBefore"] = true;
        progress["errorMessage"] = "Error: Reading selfdescription.json failed, file not found/existed";

        setResponseCodeTextLog(res, 404, progress["errorMessage"].toString(), "getSelfDescription");

    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "getSelfDescription", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}