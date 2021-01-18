import ballerina/log;
import ballerina/http;
import ballerina/encoding;

function forwardHOMessage(http:Caller caller, http:Request req) {

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
    ] = extractFwdRequestHeader(req, gloHODataRequestMessageTypes, gloInfraFwdXXRootLength, closureProgress);

    // Providing outgoing DAT JWT
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Processing the request forwarding headers");
        provideGlobalDatToken(closureProgress);

    } else {    

        log:printDebug("Info: Skipping providing DAT JWT, error happened before");

    }

    // Creating IDS Multipart header, base64UrlEncoded as header in HeaderOnly request
    json idsHeader = {};
    string idsHeaderBase64UrlEncoded = "";

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing outgoing DAT JWT");

        json|error? createIDSHeaderResult = createIDSHeader(requestMessageType);

        if (createIDSHeaderResult is json) {

            idsHeader = createIDSHeaderResult;
            idsHeaderBase64UrlEncoded = encoding:encodeBase64Url(idsHeader.toJsonString().toBytes()) ; 

        } else {

            setErrorProgresstrackingLog("Error: Creating IDS Multipart header, base64UrlEncoded as header in HeaderOnly request failed, no valid json created", "forwardHOMessage", closureProgress, createIDSHeaderResult);

        }

    } else {

        log:printDebug("Info: Skipping creating IDS Multipart header, base64UrlEncoded as header in HeaderOnly request, error happened before");

    }

    // Forwarding HeaderOnly request to provider and receiving response
    string addedIDSRequestHeaderOnlyLogProcessNoteMessage  = "";
    http:Response|error providerResponse = new;

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Creating IDS Multipart header, base64UrlEncoded as header in HeaderOnly request");
        http:Client providerEndpoint = new (provider_url, gloExternalClientConfig);

        // Removing additional request forwarding headers
        var req1 = removeFwdHeader(req, additionalHeaderKey, additionalHeaderValue);

        // Adding IDS HeaderOnly header
        req1.addHeader("header", idsHeaderBase64UrlEncoded);

        // Adding additional (Auth)header
        if (additionalHeaderKey !== "" && additionalHeaderValue !== "") {    

            req.addHeader(<@untainted>additionalHeaderKey, <@untainted>additionalHeaderValue);

        }

        // Adding FiwareService
        if (fiwareService !== "") {    

            req.addHeader("Fiware-Service", <@untainted>fiwareService);

        }

        // Adding FiwareServicePath
        if (fiwareServicePath !== "") {    

            req.addHeader("Fiware-ServicePath", <@untainted>fiwareServicePath);

        }

        // Creating explanation texts to add to header
        if (logProcessNotesJNQP == "J") {

            addedIDSRequestHeaderOnlyLogProcessNoteMessage = createFwdHOIDSRequestHeaderOnlyLogProcessNoteMessage(logProcessNotesJNQP, provider_url, path, idsHeaderBase64UrlEncoded, additionalHeaderKey, additionalHeaderValue);  

        } 

        // Forwarding HeaderOnly request to provider
        providerResponse = providerEndpoint->forward(<@untainted>path, req);

    } else {

        log:printDebug("Info: Skipping forwarding HeaderOnly request to provider and receiving response, error happened before");

    }

    // Processing provider HeaderOnly response and sending message back to caller
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Forwarding HeaderOnly request to provider and receiving response");

        if (providerResponse is http:Response) {

            log:printDebug("Success: Receiving Message: ProviderResponse StatusCode: " + providerResponse.statusCode.toJsonString() +
                            " ReasonPhrase: " + providerResponse.reasonPhrase +
                            " ContentType: " + providerResponse.getContentType());

            if (providerResponse.statusCode <= 299) { 

                log:printDebug("Success: Processing provider HeaderOnly response with StatusCode <= 299");

                if (logProcessNotesJNQP == "J") {

                    providerResponse.addHeader("LogProcessNotesHO", <@untainted>addedIDSRequestHeaderOnlyLogProcessNoteMessage);

                } 

                log:printDebug("Info: Sending response back to caller");

                var responseResult = caller->respond(<@untainted>providerResponse);

                handleResponseResult(responseResult, "forwardHOMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

            } else if (providerResponse.statusCode == 500) {

                log:printDebug("Info: Sending error response back to caller after StatusCode 500");

                var responseResult = caller->respond(<@untainted>providerResponse);

                handleResponseResult(responseResult, "forwardHOMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

            } else {
                
                setErrorProgresstrackingLog("Error: Processing provider HeaderOnly response with Status Code <= 299 failed, was:" + providerResponse.statusCode.toString() + " - " + providerResponse.reasonPhrase, "forwardHOMessage", closureProgress);
            }

        } else {

            setErrorProgresstrackingLog("Error: Processing provider HeaderOnly response failed, no valid HTTP received, ", "forwardHOMessage", closureProgress, providerResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing provider HeaderOnly response and sending message back to caller, error happened before");

    }

    // Sending final error message back to caller
    if (progress["errorBefore"] == true) {

        http:Response errorResponse = new;
        errorResponse.setPayload({"ErrorMessage": progress["errorMessage"].toJsonString()});
        errorResponse.statusCode = 500;        

        var responseResult = caller->respond(errorResponse);

        handleResponseResult(responseResult, "forwardHOMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

    }
}