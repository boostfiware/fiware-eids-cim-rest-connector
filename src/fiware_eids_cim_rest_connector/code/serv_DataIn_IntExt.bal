import ballerina/log;
import ballerina/http;
import ballerina/time;
import ballerina/system;


// Implementing this httpClientMap was necessary after finding out issues about creating a new httpClientMap for each incoming call host
// This process process is currently automated and could be extended to a fully manually controlled external process 
map<http:HttpClient> dataInIntExtSHHttpClientMap = {};

function dataInInternalExternal(http:Caller caller, http:Request req, int serviceCallTimeNano) {

    int lastServiceTimeStampNano = serviceCallTimeNano;
    string externalProviderHostURL = "";
    string userPath = "";
    string messageStructure = "";
    string responseMessageType = "";
    string idsModelVersion = "";
    string incomingDatToken = "";
    http:Response|error externalProviderHostURLResponse = new;
    string abbrServiceName = "intExt";    

    // Setting ProgressErrorTracking with closure
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };
    var closureProgress = function (boolean errorB, string errorM) {
        progress["errorBefore"] = errorB;
        progress["errorMessage"] = errorM;
    };


    // Extracting externalProviderHostURL from incoming internal call Host header and providing a httpClient in dataInIntExtSHHttpClientMap
    if (req.hasHeader("Host")) {
    
        externalProviderHostURL = "https://" + req.getHeader("Host");
        log:printDebug("Host Header: " + externalProviderHostURL);

        // Providing a httpClient
        boolean externalProviderHostURLAvailableInHTTPClientMap = dataInIntExtSHHttpClientMap.hasKey(externalProviderHostURL);

        if (externalProviderHostURLAvailableInHTTPClientMap) {

            log:printDebug("Success: CACHE-HIT: An entry for externalProviderHostURL has been found in dataInIntExtSHHttpClientMap and should hold a vlid already created httpClient");

        } else {

            // Creating new entry in dataInIntExtSHHttpClientMap
            var myHTTPSecureClientResult = http:createHttpSecureClient(<@untainted>externalProviderHostURL, gloExternalClientConfig);

            if (myHTTPSecureClientResult is http:HttpClient) {

                dataInIntExtSHHttpClientMap[externalProviderHostURL] = myHTTPSecureClientResult; 

                log:printDebug("Success: CACHE-PUT: Creating new httpClient for externalProviderHostURL and putting a new entry into dataInIntExtSHHttpClientMap");

            } else {

                setErrorProgresstrackingLog("Error: Creating new httpClient for externalProviderHostURL failed, no valid httpClient received", "dataInIntExtSH", closureProgress, myHTTPSecureClientResult);
        
            }
        }

    } else {

        setErrorProgresstrackingLog("Error: Extracting externalProviderHostURL from incoming call and providing a httpClient in dataInIntExtSHHttpClientMap failed, Host header not available in request", "dataInIntExtSH", closureProgress);

    }

    // Extracting relevant infos from incoming call ... 
    userPath = req.rawPath;

    // Deleting all SplitHeader x-* headers
    string[] allHeadersIstio = req.getHeaderNames();

    foreach var header in allHeadersIstio {

        if (header.startsWith("x-")) {
            req.removeHeader(<@untainted>header);
        }            
    }


    log:printDebug("Success: Extracting externalProviderHostURL: " + externalProviderHostURL + ", and user path for composing forward url: " + userPath + " extracted from request rawPath " + req.rawPath + " - abzüglich " + gloDataRootLength.toString());

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("01", abbrServiceName, "Preprocessing incoming call", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Providing DAT JWT for outgoing messages
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Validating DAT JWT + validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorization, if activated");

        provideGlobalDatToken(closureProgress);

    } else {    

        log:printDebug("Info: Skipping providing DAT JWT for outgoing messages, error happened before");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("04", abbrServiceName, "Providing DAT JWT", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Adding SplitHeader headers
    string messageUUID = system:uuid();
    string messageTime = time:toString(time:currentTime());
    var req1 = addSHHeader(req, "ids:RequestMessage", messageUUID, messageTime, gloDatTokenJWT, "", "", "", "");

    // Calling externalProviderHostURL backend with httpClient read from dataInIntExtSHHttpClientMap, forwarding request and receiving response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing DAT JWT and SplitHeader headers for outgoing messages");

        // Reading httpClient for externalProviderHostURL from dataInIntExtSHHttpClientMap
        http:HttpClient? callHTTPClient = dataInIntExtSHHttpClientMap[externalProviderHostURL];

        if (callHTTPClient is http:HttpClient) {

            log:printDebug("Success: Reading httpClient for externalProviderHostURL from dataInIntExtSHHttpClientMap containing: " + dataInIntExtSHHttpClientMap.length().toString() + " elementes");

            if (gloLogLevelNotOffOrError) {

                lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("05", abbrServiceName, "Fetching httpClient from map", serviceCallTimeNano, lastServiceTimeStampNano);

            }

            // Forwarding SplitHeader request to externalProviderHostURL/userPath, client instantiation realized with dataInIntExtSHHttpClientMap
            externalProviderHostURLResponse = callHTTPClient->forward(<@untainted>userPath, req);

        } else {

            setErrorProgresstrackingLog("Error: Reading httpClient for externalProviderHostURL from dataInIntExtSHHttpClientMap failed, no valid httpClient received", "dataInIntExtSH", closureProgress, callHTTPClient);

        }

    } else {    

        log:printDebug("Info: Skipping calling externalProviderHostURL backend with httpClient read from dataInIntExtSHHttpClientMap, forwarding request and receiving response, error happened before");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("06", abbrServiceName, "Receiving externalProviderHostURL response", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Processing externalProviderHostURL response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Calling externalProviderHostURL backend with httpClient read from dataInIntExtSHHttpClientMap, forwarding request and receiving response");

        if (externalProviderHostURLResponse is http:Response) {

            log:printDebug("Success: Receiving externalProviderHostURL response message: StatusCode: " + externalProviderHostURLResponse.statusCode.toJsonString() +
                " ReasonPhrase: " + externalProviderHostURLResponse.reasonPhrase +
                " ContentType: " + externalProviderHostURLResponse.getContentType());

            if (externalProviderHostURLResponse.statusCode <= 299) { 

                log:printDebug("Success: Receiving externalProviderHostURL response message with StatusCode <= 299");

                // Processing incoming SplitHeader request from incoming externalProviderHostURL
                if (externalProviderHostURLResponse.hasHeader("IDS-SecurityToken-TokenValue")) {

                    log:printDebug("Success: Detecting incoming externalProviderHostURL response message as SplitHeader message");

                    // Extracting relevant information from SplitHeader IDS headers
                    if (externalProviderHostURLResponse.hasHeader("IDS-Messagetype") && externalProviderHostURLResponse.hasHeader("IDS-ModelVersion") && externalProviderHostURLResponse.hasHeader("IDS-SecurityToken-TokenValue")) {
                    
                        responseMessageType = externalProviderHostURLResponse.getHeader("IDS-Messagetype");
                        idsModelVersion = externalProviderHostURLResponse.getHeader("IDS-ModelVersion");
                        incomingDatToken = externalProviderHostURLResponse.getHeader("IDS-SecurityToken-TokenValue");

                        // Deleting all SplitHeader IDS-* headers
                        string[] allHeaders = externalProviderHostURLResponse.getHeaderNames();

                        foreach var header in allHeaders {

                            if (header.startsWith("IDS-")) {
                                externalProviderHostURLResponse.removeHeader(<@untainted>header);
                            }            
                        }

                    } else {

                        setErrorProgresstrackingLog("Error: Reading relevant IDS header from incoming externalProviderHostURL respose message failed, IDS-Messagetype, IDS-ModelVersion and IDS-SecurityToken-TokenValue header not all available", "dataInIntExtSH", closureProgress);

                    }

                } else {

                    setErrorProgresstrackingLog("Error: Reading incoming response message failed, no SplitHeader externalProviderHostURL respose message", "dataInIntExtSH", closureProgress);

                }

                // Filtering incoming externalProviderHostURL message for allowed responseMessageTypes
                if (progress["errorBefore"] == false) {

                    log:printDebug("Success: Processing incoming SplitHeader request from incoming externalProviderHostURL");

                    if (gloSHDataResponseMessageTypes.indexOf(responseMessageType) is ()) {

                        setErrorProgresstrackingLog("Error: Filtering for only ids:ResponseMessage failed, was: " + responseMessageType + ", no other message types implemented.", "dataInIntExtSH", closureProgress);

                    } 

                } else {    

                    log:printDebug("Info: Skipping filtering incoming externalProviderHostURL message for allowed responseMessageTypes, error happened before");

                }

                if (gloLogLevelNotOffOrError) {

                    lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("07", abbrServiceName, "Preprocessing incoming externalProviderHostURL response message", serviceCallTimeNano, lastServiceTimeStampNano);

                }

                // Validating DAT JWT from incoming externalProviderHostURL message
                if (progress["errorBefore"] == false) {
                    
                    log:printDebug("Success: Filtering incoming externalProviderHostURL message for allowed responseMessageTypes");

                    validateIncomingDatToken(<@untainted>incomingDatToken, closureProgress);

                } else {    

                    log:printDebug("Info: Skipping validating DAT JWT from incoming externalProviderHostURL message, error happened before");

                }

                if (gloLogLevelNotOffOrError) {

                    lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("08", abbrServiceName,  "Validating DAT JWT", serviceCallTimeNano, lastServiceTimeStampNano);

                }

                // Sending incoming externalProviderHostURL response message back to interal caller
                if (progress["errorBefore"] == false) {
                    
                    log:printDebug("Success: Validating DAT JWT from incoming externalProviderHostURL message");

                    var responseResult = caller->respond(<@untainted>externalProviderHostURLResponse);

                    handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

                } else {    

                    log:printDebug("Info: Skipping sending incoming externalProviderHostURL response message back to interal caller, error happened before");

                }

            } else {

                setErrorProgresstrackingLog("Error: Receiving SplitHeader externalProviderHostURL response with StatusCode <= 299 failed, was: " + externalProviderHostURLResponse.statusCode.toString() + " - " + externalProviderHostURLResponse.reasonPhrase, "dataInIntExtSH", closureProgress);

            }

        } else {

            setErrorProgresstrackingLog("Error: Processing externalProviderHostURL response failed, no valid HTTP received", "dataInIntExtSH", closureProgress, externalProviderHostURLResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing externalProviderHostURL response, error happened before");

    }

    // Sending error message back to internal caller
    if (progress["errorBefore"] == true) {

        http:Response errorResponse = new;
        errorResponse.setPayload({"ErrorMessage": progress["errorMessage"]});
        errorResponse.statusCode = 500;

        var responseResult = caller->respond(errorResponse);

        handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

    } 
}