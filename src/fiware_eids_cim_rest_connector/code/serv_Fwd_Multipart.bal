import ballerina/log;
import ballerina/file;
import ballerina/http;
import ballerina/mime;

function forwardMPMessage(http:Caller caller, http:Request req) {

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
    ] = extractFwdRequestHeader(req, gloMPFwdRequestMessageTypes, gloInfraFwdXXRootLength, closureProgress);

    // Providing outgoing DAT JWT
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Processing the request forwarding headers");
        provideGlobalDatToken(closureProgress);

    } else {    

        log:printDebug("Info: Skipping providing DAT JWT, error happened before");

    }

    // Creating IDS header
    json idsHeader = {};
    mime:Entity multipartHeader = new;

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing outgoing DAT JWT");

        json|error? createIDSHeaderResult = createIDSHeader(requestMessageType);

        if (createIDSHeaderResult is json) {

            idsHeader = createIDSHeaderResult;
            multipartHeader = createMPHeader(idsHeader);

        } else {

            setErrorProgresstrackingLog("Error: Creating IDS header failed", "forwardMPMessage", closureProgress, createIDSHeaderResult);

        }

    } else {

        log:printDebug("Info: Skipping creating IDS header, error happened before");

    }

    // Creating IDS Multipart payload with selfdescription.json
    json selfDescriptionJSON = {};
    mime:Entity multipartPayload = new;
    mime:Entity[] multipartMessage = [];

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Creating IDS header");

        if (gloMPFwdRequestMessageTypesWithSelfDescriptionPayload.indexOf(requestMessageType) is int) {

            if (file:exists(gloFilePathSelfDesriptionInBallerina)) {

                json|error readSelfDescriptionResult = readFileSelfDescriptionJsonLd();

                if (readSelfDescriptionResult is json) {

                    selfDescriptionJSON = readSelfDescriptionResult;
                    multipartPayload = createMPPayload(readSelfDescriptionResult);
                    multipartMessage = [multipartHeader, multipartPayload];
                    log:printDebug("Success: Creating IDS Multipart payload with selfdescription.json");

                } else {

                    setErrorProgresstrackingLog("Error: Creating IDS Multipart payload with selfdescription.json failed, no valid JSON", "forwardMPMessage", closureProgress, readSelfDescriptionResult);

                }

            } else {

                setErrorProgresstrackingLog("Error: Creating IDS Multipart payload with selfdescription.json failed, file not found/existed", "forwardMPMessage", closureProgress);

            }

        } else {
            
            log:printDebug("Info: Skipping creating IDS Multipart payload with selfdescription.json, not needed in forwarded RequestMessageType: " + requestMessageType);

        }

    } else {

        log:printDebug("Info: Skipping creating IDS Multipart payload with selfdescription.json, error happened before");

    }

    // Creating IDS Multipart payload with Broker QueryText RDF payload
    string queryTextPayload = "";

    if (progress["errorBefore"] == false) {

        if (gloMPFwdRequestMessageTypesWithPlainTextQueryMessagePayload.indexOf(requestMessageType) is int) {

            string|error readQueryTextPayloadResult = req.getTextPayload();

            if (readQueryTextPayloadResult is string) {

                queryTextPayload = readQueryTextPayloadResult;
                multipartPayload.setContentDisposition(setMPContentDispositionForFormData("payload"));
                multipartPayload.setBody(<@untainted> queryTextPayload);
                multipartMessage = [multipartHeader, multipartPayload];
                log:printDebug("Success: Creating IDS Multipart payload with Broker QueryText RDF payload");

            } else {

                setErrorProgresstrackingLog("Error: Creating IDS Multipart payload with Broker QueryText RDF payload failed, no valid String", "forwardMPMessage", closureProgress, readQueryTextPayloadResult);

            }

        } else {

            log:printDebug("Info: Skipping creating IDS Multipart payload with Broker QueryText RDF payload, not needed, RequestMessageType: " +  requestMessageType);

        }

    } else {

        log:printDebug("Info: Skipping creating IDS Multipart payload with Broker QueryText RDF payload, error happened before");
    }

    // Finishing IDS Multipart message only with header part without payload part
    if (progress["errorBefore"] == false) {

        if (gloMPFwdRequestMessageTypesWithoutAnyPayload.indexOf(requestMessageType) is int) {

            multipartMessage = [multipartHeader];
            log:printDebug("Success: Finishing IDS Multipart message only with header part without payload part. Type was: " +  requestMessageType);

        } else {

            log:printDebug("Info: Skipping finishing IDS Multipart message only with header part without payload part, not needed, RequestMessageType:  Type was: " +  requestMessageType);

        }

    } else {

        log:printDebug("Info: Skipping finishing IDS Multipart Message only with Header without Payload, error happened before");

    }

    // Forwarding Multipart request to provider and receiving response
    http:Request providerRequest = new;
    http:Response|error providerResponse = new;
    
    if (progress["errorBefore"] == false) {

        http:Client providerEndpoint = new (provider_url, gloExternalClientConfig);
        providerRequest.setBodyParts(multipartMessage, contentType = mime:MULTIPART_FORM_DATA);
        providerResponse = providerEndpoint->post(<@untainted>path, providerRequest);

    } else {

        log:printDebug("Info: Skipping forwarding Multipart request to provider and receiving response, error happened before");

    }

    // Processing provider Multipart response
    mime:Entity[] providerBodyParts = [];
    json[] bodyPartJsonContentArray = [];

    if (progress["errorBefore"] == false) {

        if (providerResponse is http:Response) {
            log:printDebug("Success: Forwarding Multipart request to provider and receiving response");
            log:printDebug("Success: Processing provider Multipart response, StatusCode: " + providerResponse.statusCode.toJsonString() + " ReasonPhrase: " + providerResponse.reasonPhrase + " ContentType: " + providerResponse.getContentType());

            var bodyParts = providerResponse.getBodyParts();

            if (bodyParts is mime:Entity[] && (providerResponse.statusCode == 200 || providerResponse.statusCode == 500)) { 

                if (logProcessNotesJNQP == "N") {

                    providerBodyParts = bodyParts;

                } else {

                    bodyPartJsonContentArray = getMPBodyPartJsonContentArray(bodyParts, closureProgress);

                }

            } else {

                setErrorProgresstrackingLog("Error: Processing provider Multipart response failed, no valid HTTP response with StatusCode 200 or with programmatic ErrorCode 500 received", "forwardMPMessage", closureProgress);

            }

        } else {

            setErrorProgresstrackingLog("Error: Processing provider Multipart response failed, no valid HTTP response received", "forwardMPMessage", closureProgress, providerResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing provider Multipart response, error happened before");

    }


    // Sending provider response back to the caller
    http:Response res = new;

    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Processing provider Multipart response");

        if (logProcessNotesJNQP == "N") {

            res.setBodyParts(<@untainted>providerBodyParts);
            res.statusCode = 200;

        } else {

            string callerResponsePayload =
                "* Message of type: " + requestMessageType + " was sent to provider url: " + provider_url + path+ "\n\n" + "* Multipart request header to provider: \n" + idsHeader.toJsonString()+ "\n-----> End of Multipart request header\n\n";

            if (!(selfDescriptionJSON == {})) {

                callerResponsePayload = callerResponsePayload + "Selfdescription as Multipart request payload to provider attached: \n" + selfDescriptionJSON.toJsonString() + "\n-----> End of Selfdescription as Multipart request payload\n\n";

            }

            if (queryTextPayload !== "") {

                callerResponsePayload = callerResponsePayload +  "QueryTextPayload as Multipart request payload to provider attached: \n" + queryTextPayload + "\n-----> End of QueryTextPayload as Multipart request payload\n\n\n";

            }

            callerResponsePayload = callerResponsePayload + "\n*** The following Multipart response was received from provider: \n\n";

            callerResponsePayload = callerResponsePayload + "\n*Provider Mulitpart response header\n" + bodyPartJsonContentArray[0].toJsonString() + "\n-----> Provider Mulitpart response header\n" + "\n*Provider Mulitpart response payload\n";
            
            if (bodyPartJsonContentArray.length()==2) {

                callerResponsePayload = callerResponsePayload + bodyPartJsonContentArray[1].toJsonString() + "\n-----> Provider Mulitpart response payload\n";

            }
             
            
            res.setPayload(<@untainted>callerResponsePayload);
            res.statusCode = 200;            
            log:printDebug("Info: Sending response back to caller");

        }

    } else {

        res.setPayload({"ErrorMessage": progress["errorMessage"].toJsonString()});
        res.statusCode = 500;

    }
    
    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "forwardMPMessage", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}