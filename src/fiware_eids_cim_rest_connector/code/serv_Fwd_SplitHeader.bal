import ballerina/log;
import ballerina/http;
import ballerina/time;
import ballerina/system;

function forwardSHMessage(http:Caller caller, http:Request req) {

    // ProgressErrorTracking with closure
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };
    var closureProgress = function (boolean errorB, string errorM) {
        progress["errorBefore"] = errorB;
        progress["errorMessage"] = errorM;
    };

    // Processing the request forwarding headers
    var [
        provider_url, 
        path, 
        requestMessageType, 
        logProcessNotesJNQP, 
        additionalHeaderKey, 
        additionalHeaderValue,
        fiwareService,
        fiwareServicePath
    ] = extractFwdRequestHeader(req, gloSHDataRequestMessageTypes, gloInfraFwdXXRootLength, closureProgress);

    // Providing outgoing DAT JWT
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Processing the request forwarding headers");
        provideGlobalDatToken(closureProgress);

    } else {    

        log:printDebug("Info: Skipping providing outgoing DAT JWT, error happened before");

    }

    http:Response|error providerResponse = new;
    string addedIDSRequestSplitHeaderLogProcessNoteMessage = "";

    // Preparing and forwarding SplitHeader request to provider and receiving response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing outgoing DAT JWT");
        http:Client providerEndpoint = new (provider_url, gloExternalClientConfig);

        // Removing additional request forwarding headers
        var req1 = removeFwdHeader(req, additionalHeaderKey, additionalHeaderValue);

        // Adding SplitHeader headers
        // Preventing deltas between messages and logs with local variables as reference
        string messageUUID = system:uuid();
        string messageTime = time:toString(time:currentTime());
        string locDatTokenJWT = gloDatTokenJWT;
        var req2 = addSHHeader(req1, requestMessageType, messageUUID, messageTime, locDatTokenJWT, additionalHeaderKey, additionalHeaderValue, fiwareService, fiwareServicePath);

        // Creating explanation texts
        addedIDSRequestSplitHeaderLogProcessNoteMessage = createFwdSHIDSRequestSplitHeaderLogProcessNoteMessage(logProcessNotesJNQP, provider_url, path, messageUUID, messageTime, locDatTokenJWT, additionalHeaderKey, additionalHeaderValue);

        // Forwarding SplitHeader request to provider
        providerResponse = providerEndpoint->forward(<@untainted>path, req2);
        
    } else {

        log:printDebug("Info: Skipping preparing and Sending SplitHeader Request to Provider and receiving Response, error happened before");

    }

    // Processing provider SplitHeader response and sending message back to caller
    if (progress["errorBefore"] == false) {

        if (providerResponse is http:Response) {

            log:printDebug("Success: reparing and forwarding SplitHeader request to provider and receiving response");
            log:printDebug("Success: Receiving Response: StatusCode: " + providerResponse.statusCode.toJsonString() +
                " ReasonPhrase: " + providerResponse.reasonPhrase +
                " ContentType: " + providerResponse.getContentType());

            if (providerResponse.statusCode <= 299) { 

                log:printDebug("Success: Processing provider SplitHeader response with StatusCode <= 299");

                if (logProcessNotesJNQP == "J") {

                    providerResponse.addHeader("LogProcessNotesSH", <@untainted>addedIDSRequestSplitHeaderLogProcessNoteMessage);

                } 

                var responseResult = caller->respond(<@untainted>providerResponse);

                handleResponseResult(responseResult, "forwardSHMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

            } else if (providerResponse.statusCode == 500) {

                var responseResult = caller->respond(<@untainted>providerResponse);

                handleResponseResult(responseResult, "forwardSHMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

            } else {

                setErrorProgresstrackingLog("Error: Processing provider SplitHeader response with Status Code <= 299 failed, was: " + providerResponse.statusCode.toString() + " - " + providerResponse.reasonPhrase, "forwardSHMessage", closureProgress);
            }

        } else {

            setErrorProgresstrackingLog("Error: Processing provider SplitHeader response failed, no valid HTTP response received", "forwardSHMessage", closureProgress, providerResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing provider Splitheader response, error happened before");

    }

    // Sending Final Error Messageback to Caller
    if (progress["errorBefore"] == true) {

        http:Response errorResponse = new;
        errorResponse.setPayload({"ErrorMessage": progress["errorMessage"].toJsonString()});
        errorResponse.statusCode = 500;        
        
        var responseResult = caller->respond(errorResponse);

        handleResponseResult(responseResult, "forwardSHMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

    } 
}