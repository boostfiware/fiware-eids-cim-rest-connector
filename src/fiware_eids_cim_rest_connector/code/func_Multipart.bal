import ballerina/log;
import ballerina/mime;


function createMPHeader(json idsHeader) returns mime:Entity {

    // Creating Multipart header with IDS Header
    mime:Entity locMultipartHeader = new;
    locMultipartHeader.setContentDisposition(setMPContentDispositionForFormData("header"));
    locMultipartHeader.setBody(idsHeader);
    mime:InvalidContentTypeError? contentType = locMultipartHeader.setContentType("application/ld+json");      
    log:printDebug("Success: Creating MP header with IDS Header: " + idsHeader.toJsonString());

    return locMultipartHeader;

}


function createMPPayload(json jsonPayload) returns mime:Entity {

    // Creating Multipart payload, plaintextmessage is extracted with function extractMPBodyPartJsonContent
    mime:Entity locMultipartPayload = new;
    locMultipartPayload.setContentDisposition(setMPContentDispositionForFormData("payload"));

    string stringPayload = jsonPayload.toJsonString();
    json|error plainTextCheckResult = jsonPayload.plaintextmessage;

    if (plainTextCheckResult is error) {

        locMultipartPayload.setBody(jsonPayload);
        mime:InvalidContentTypeError? contentType = locMultipartPayload.setContentType("application/ld+json");      
        log:printDebug("Success: Creating MP payload with Content-Type application/ld+json: " + stringPayload);

    } else {

        string plainTextMessage = stringPayload.substring(21, stringPayload.length() -2); 
        log:printDebug("Success: Extracting original plaintext string from json representation: " + stringPayload);
        locMultipartPayload.setBody(plainTextMessage);
        mime:InvalidContentTypeError? contentType = locMultipartPayload.setContentType("text/plain");      
        log:printDebug("Success: Creating MP payload with Content-Type text/plain: " + plainTextMessage);
    }

    return locMultipartPayload;

}


function getMPBodyPartJsonContentArray(mime:Entity[] bodyParts, function (boolean, string) closureProgressError) returns @tainted json[] {

    // Shifting Multipart bodyparts into json array
    json[] locBodyPartJsonContentArray = [];
    int counter = 0;
    log:printDebug("Success: Receiving MultiPart request, ready for extracting bodyparts");

    foreach var bodyPart in bodyParts {

        json|error extractMPBodyPartJsonContentResult = extractMPBodyPartJsonContent(bodyPart, closureProgressError);  

        if (extractMPBodyPartJsonContentResult is json) {

            locBodyPartJsonContentArray[counter] = extractMPBodyPartJsonContentResult; 

        } else {

            locBodyPartJsonContentArray[counter] = "Error message" + extractMPBodyPartJsonContentResult.reason(); 
            setErrorProgresstrackingLog("Error: Shifting MultiPart bodypart into json array failed, no json extracted, ", "getMPBodyPartJsonContentArray", closureProgressError, extractMPBodyPartJsonContentResult);

        }

        counter += 1;
    }

    log:printDebug("Success: Shifting MultiPart bodypart into json array with in total " + counter.toString() + " bodyparts");

    return locBodyPartJsonContentArray;
    
}


function extractMPBodyPartJsonContent(mime:Entity responseEntity, function (boolean, string) closureProgressError) returns @tainted json|error {

    // Converting bodyparts of Multipart messages into json, if not already available
    string errorMessage = "";

    string contentType = getMPBodyPartContentType(responseEntity.getContentType(), closureProgressError);
    log:printDebug("Success: Extracting Content-Type from Multipart entity: " + contentType);

    if (contentType == "application/ld+json" || contentType == "application/json") {

        var jsonEntity = responseEntity.getJson();
        if (jsonEntity is json) {

            return jsonEntity;

        } else {

            return error("Error: Extracting json/ld+json entity failed, no valid json");

        }  

    // THE FOLLOWING IS NOT A VALID Content-Type, it is just a work around to handle the incorrect FHG EIS MetaData Broker Content-Type application/json+ld
    } else if (contentType == "application/json+ld") { 

        log:printDebug("Info: Recall!!! FHG MetaData Broker exception, invalid Content-Type to be deleted later");
        var jsonEntity = responseEntity.getJson();

        if (jsonEntity is json) {

            return jsonEntity;

        } else {

            return error("Error: Extracting json/json+ld entity failed, no valid json");

        }

    } else if (contentType == "text/plain") {

        var textEntity = responseEntity.getText();

        if (textEntity is string) {

            return {"plaintextmessage": textEntity};

        } else {

            return error("Error: Extracting text/plain entity failed, no valid string");

        }

    } else {

            return error("Error: Presented bodypart did not contain application/ld+json, application/json+ld!!! or text/plain BUT " + contentType + ", no other Content-Types allowed");

    }
}


function getMPBodyPartContentType(string contentType, function (boolean, string) closureProgressError) returns string {

    // Extracting MediaTypes of incoming Multipart messages
    var getMediaTypeResult = mime:getMediaType(contentType);

    if (getMediaTypeResult is mime:MediaType) {

        return getMediaTypeResult.getBaseType();

    } else { 

        setErrorProgresstrackingLog("Error: Extracting MP bodypart's Content-Type failed, no known mime:MediaType, ", 
            "getMPBodyPartContentType", closureProgressError, getMediaTypeResult);

        return "Error: Extracting MP bodypart's Content-Type failed, no known mime:MediaType"; 

    }
}


function setMPContentDispositionForFormData(string partName) returns mime:ContentDisposition {

    // Setting ContentDisposition for Multipart messages
    mime:ContentDisposition contentDisposition = new;
    contentDisposition.name = partName;
    contentDisposition.disposition = "form-data";

    return contentDisposition;
    
}