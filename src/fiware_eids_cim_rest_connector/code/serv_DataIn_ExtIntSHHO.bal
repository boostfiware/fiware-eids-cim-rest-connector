import ballerina/log;
import ballerina/http;
import ballerina/time;
import ballerina/system;
import ballerina/encoding;
import ballerina/stringutils;
import ballerina/lang.'string;


function dataInExtIntSHHO(http:Caller caller, http:Request req, int serviceCallTimeNano) {

    int lastServiceTimeStampNano = serviceCallTimeNano;
    string userPath = "";
    string messageStructure = "";
    string requestMessageType = "";
    string idsModelVersion = "";
    string incomingDatToken = "";
    http:Response|error providerHostResponse = new;
    string abbrServiceName = "extInt";    

    // Setting ProgressErrorTracking with closure
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };
    var closureProgress = function (boolean errorB, string errorM) {
        progress["errorBefore"] = errorB;
        progress["errorMessage"] = errorM;
    };

    // Extracting relevant infos from incoming external EIDS/IDS call
    userPath = req.rawPath.substring(gloDataRootLength);

    // Processing incoming SplitHeader request 
    if (req.hasHeader("IDS-SecurityToken-TokenValue")) {

        messageStructure = "SHMessage";
        log:printDebug("Success: Detecting incoming message as SplitHeader message");

        // Extracting relevant information from SplitHeader IDS headers

        if (req.hasHeader("IDS-Messagetype") && req.hasHeader("IDS-ModelVersion") && req.hasHeader("IDS-SecurityToken-TokenValue")) {
        
            requestMessageType = req.getHeader("IDS-Messagetype");
            idsModelVersion = req.getHeader("IDS-ModelVersion");
            incomingDatToken = req.getHeader("IDS-SecurityToken-TokenValue");

        } else {

            setErrorProgresstrackingLog("Error: Reading relevant IDS header from incoming message failed, IDS-Messagetype, IDS-ModelVersion and IDS-SecurityToken-TokenValue header not all available", "dataInExtIntSHHO", closureProgress);

        }

        // Deleting all SplitHeader IDS-* headers
        string[] allHeaders = req.getHeaderNames();

        foreach var header in allHeaders {

            if (header.startsWith("IDS-")) {
                req.removeHeader(<@untainted>header);
            }            
        }

    // Processing incoming HeaderOnly request 
    } else if (req.hasHeader("header")) {

        messageStructure = "HHMessage";
        log:printDebug("Success: Detecting incoming message as HeaderOnly message");

        // Extracting HeaderOnly IDS header header
        string headerHeaderEncoded = req.getHeader("header");
        log:printDebug("Success: Extracting header header: " + headerHeaderEncoded);

        // Decoding the base64Url encoded header Header
        map<json> headerHeaderDecodedJson = {};

        // Extracting relevant information from SplitHeader IDS Headers
        byte[]|error headerHeaderEncodedByteArray = encoding:decodeBase64Url(headerHeaderEncoded);

        if (headerHeaderEncodedByteArray is byte[]) {

            string|error headerHeaderDecodedStringResult = 'string:fromBytes(headerHeaderEncodedByteArray);

            if (headerHeaderDecodedStringResult is string) {
                log:printDebug("Success: Decoding header header: " + headerHeaderDecodedStringResult);

                json|error headerHeaderDecodedJsonResult = headerHeaderDecodedStringResult.fromJsonString();

                if (headerHeaderDecodedJsonResult is json) {

                    // Extracting requestMessageType
                    map<json> headerHeaderDecodedJsonResultMap = <map<json>>headerHeaderDecodedJsonResult;
                    requestMessageType = headerHeaderDecodedJsonResultMap["@type"].toJsonString();

                    // Extracting IDS ModelVersion
                    idsModelVersion = headerHeaderDecodedJsonResultMap["ids:modelVersion"].toJsonString();

                    // Extracting DAT JWT
                    map<json> securityTokenResult = <map<json>>headerHeaderDecodedJsonResultMap["ids:securityToken"];
                    incomingDatToken = securityTokenResult["ids:tokenValue"].toString();

                    if (requestMessageType == "" || idsModelVersion == ""  || incomingDatToken == "") {
                    
                        setErrorProgresstrackingLog("Error: Extracting all relevant IDS information failed, @type, ids:modelVersion and ids:securityToken.ids:tokenValue were not all presented", "dataInExtIntSHHO", closureProgress);

                    } 

                    // Removing header header for the upcoming forwarding
                    req.removeHeader("header");

                    log:printDebug("Success: Extracting all relevant info from HeaderOnly header header: " + requestMessageType + " - " + idsModelVersion + " - " + incomingDatToken);

                } else {

                    setErrorProgresstrackingLog("Error: Converting header header from string to json failed, ", "dataInExtIntSHHO", closureProgress, headerHeaderDecodedJsonResult);

                }

            } else {

                setErrorProgresstrackingLog("Error: Converting header header from byteArray to string failed, ", "dataInExtIntSHHO", closureProgress, headerHeaderDecodedStringResult);

            }

        } else {

            setErrorProgresstrackingLog("Error: Decoding base64Url encoded header header failed, no valid byteArray, ", "dataInExtIntSHHO", closureProgress, headerHeaderEncodedByteArray);
        }

    } else {

        setErrorProgresstrackingLog("Error: Reading incoming message failed, no SplitHeader and no HeaderOnly message", "dataInExtIntSHHO", closureProgress);

    }

    // Filtering for allowed requestMessageTypes
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Extracting relevant infos from incoming external EIDS/IDS call");

        if (gloDataInSHHOExtDataRequestMessageTypes.indexOf(requestMessageType) is ()) {

            setErrorProgresstrackingLog("Error: Filtering for only ids:RequestMessage or ids:QueryMessage failed, was: " + requestMessageType + ", no other message types implemented.", "dataInExtIntSHHO", closureProgress);

        } 

    } else {    

        log:printDebug("Info: Skipping filtering for only allowed requestMessageTypes, error happened before");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("01", abbrServiceName, "Preprocessing incoming call", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Validating DAT JWT
    if (progress["errorBefore"] == false) {
        
        log:printDebug("Success: Filtering for only allowed requestMessageTypes");

        validateIncomingDatToken(<@untainted>incomingDatToken, closureProgress);

    } else {    

        log:printDebug("Info: Skipping validating DAT JWT, error happened before");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("02", abbrServiceName,  "Validating DAT JWT", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorization, if activated
    if (progress["errorBefore"] == false) {
        
        log:printDebug("Success: Validating DAT JWT");

        if (gloKeyRockActivationExtInt) {

            string[] roleStringArray = [""]; 
            string incomingKeyRockToken = "";
            string fiwareService = "";
            boolean keyRockTokenValidatedFromCache = false;
            string combinedRequestAuthZForceCacheKey = "";
            
            if (req.hasHeader("X-Auth-Token")) {

                incomingKeyRockToken = req.getHeader("X-Auth-Token");
                req.removeHeader("X-Auth-Token");

            } 

            if (req.hasHeader("Fiware-Service")) {

                fiwareService = req.getHeader("Fiware-Service");

            } 

            string[] jwtSplits = stringutils:split(incomingKeyRockToken, "\\.");        

            // Validating FIWARE KeyRock X-AUTH-TOKEN JWT 3-part-structure and existance of a Fiware-Service header/value
            if (jwtSplits.length() != 3 || fiwareService == "") {

                setErrorProgresstrackingLog("Error: Validating FIWARE KeyRock X-AUTH-TOKEN JWT 3-part-structure failed, no valid JWT received, or the mandatory header Fiware-Service was missing", "dataInExtIntSHHO", closureProgress);

            }

            // Validating FIWARE KeyRock X-AUTH-TOKEN JWT signature
            if (progress["errorBefore"] == false) {

                log:printDebug("Success: Validating FIWARE KeyRock X-AUTH-TOKEN JWT 3-part-structure and existance of a Fiware-Service header/value");

                keyRockTokenValidatedFromCache = validateIncomingKeyRockTokenSignature(incomingKeyRockToken, closureProgress);

            } else {    

                log:printDebug("Info: Skipping validating FIWARE KeyRock X-AUTH-TOKEN JWT signature, error happened before");

            }

            // Validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorizaton
            if (progress["errorBefore"] == false) {

                log:printDebug("Success: Validating FIWARE KeyRock X-AUTH-TOKEN JWT signature");

                // Creating hash value of the FIWARE KeyRock X-AUTH-TOKEN payload for combined Cache-Key
                string hashCodePayloadJWT = stringutils:hashCode(jwtSplits[1]).toString();
                log:printDebug("Hash KeyRockJWTPayload: " + hashCodePayloadJWT);

                // Creating hash value of the combined AuthorizationString for a combined Cache-Key
                string concatAuthorizationString = req.method + userPath + fiwareService + gloDatEndpointUrl;
                string hashCodeConcatAuthorizationString = stringutils:hashCode(concatAuthorizationString).toString();
                log:printDebug("Hash ConcatAuthorizationString: " + hashCodeConcatAuthorizationString);

                // Creating concatenated request string for combined-key cache handling
                combinedRequestAuthZForceCacheKey = hashCodePayloadJWT + hashCodeConcatAuthorizationString;

                // Validating cache hit for validated token and also a cache hit for combined-key cache for handling
                if (keyRockTokenValidatedFromCache && gloConnectorCache.hasKey(combinedRequestAuthZForceCacheKey)) {

                    log:printDebug("Success: CACHE-HIT: concatenated request string validated from Cache + the FIWARE KeyRock X-AUTH-TOKEN that is also validated from cache, including the contained roles, both together enable to fetch the authorization response from cache without reevaluating.");

                } else {

                    string[]? roleArrayResult = validateIncomingKeyRockToken(incomingKeyRockToken, closureProgress);
                    roleStringArray = roleArrayResult is string[] ? roleArrayResult : [""];

                    if (roleArrayResult is string[]) {
        
                        checkXACMLAuthorization(combinedRequestAuthZForceCacheKey, req.method, userPath, fiwareService, gloDatEndpointUrl, roleStringArray, closureProgress);

                    } 
                }

            } else {    

                log:printDebug("Info: Skipping validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorizaton, error happened before");

            }

        } else {

            log:printDebug("Info: Skipping validating FIWARE KeyRock X-AUTH-TOKEN JWT, keyRock validation not activated");

        }

    } else {   

        log:printDebug("Info: Skipping validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorization, if activated, error happened before");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("03", abbrServiceName, "Validating KeyRock JWT and authorization", serviceCallTimeNano, lastServiceTimeStampNano);

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

    // Calling gloProviderRestApiEndpoint forwarding request and receiving response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Providing DAT JWT for outgoing messages");

        // Forwarding SplitHeader/HeaderOnly request to gloProviderRestApiEndpoint/userPath
        providerHostResponse = gloProviderRestApiEndpoint->forward(<@untainted>userPath, req);

    } else {    

        log:printDebug("Info: Skipping calling gloProviderRestApiEndpoint forwarding request and receiving response");

    }

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("06", abbrServiceName, "Receiving gloProviderRestApiEndpoint response", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Processing gloProviderRestApiEndpoint response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Calling gloProviderRestApiEndpoint forwarding request and receiving response");

        if (providerHostResponse is http:Response) {

            log:printDebug("Success: Receiving gloProviderRestApiEndpoint response message: StatusCode: " + providerHostResponse.statusCode.toJsonString() +
                " ReasonPhrase: " + providerHostResponse.reasonPhrase +
                " ContentType: " + providerHostResponse.getContentType());

            if (providerHostResponse.statusCode <= 299) { 

                log:printDebug("Success: Receiving gloProviderRestApiEndpoint response message with StatusCode <= 299");
                string responseMessageType = "ids:ResponseMessage";
                string locDatTokenJWT = gloDatTokenJWT;
                string messageUUID = system:uuid();
                string messageTime = time:toString(time:currentTime());

                if (messageStructure == "SHMessage"){

                    // Adding IDS SplitHeader header to gloProviderRestApiEndpoint response message
                    providerHostResponse = addSHResponseHeader(providerHostResponse, responseMessageType, messageUUID, messageTime, locDatTokenJWT);

                    if (gloLogLevelNotOffOrError) {

                        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("07", abbrServiceName, "Preparing IDS SplitHeader", serviceCallTimeNano, lastServiceTimeStampNano);

                    }

                    var responseResult = caller->respond(<@untainted>providerHostResponse);

                    handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

                } else {

                    // Adding IDS HeaderOnly header to gloProviderRestApiEndpoint response message
                    json idsHeader = {};
                    string idsHeaderBase64UrlEncoded = "";

                    json|error? createIDSHeaderResult = createIDSHeader(responseMessageType);

                    if (createIDSHeaderResult is json) {

                        idsHeader = createIDSHeaderResult;
                        idsHeaderBase64UrlEncoded = encoding:encodeBase64Url(idsHeader.toJsonString().toBytes()) ; 
                        providerHostResponse.addHeader("header", idsHeaderBase64UrlEncoded);

                        if (gloLogLevelNotOffOrError) {

                            lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("07", abbrServiceName, "Preparing IDS HeaderOnly", serviceCallTimeNano, lastServiceTimeStampNano);

                        }

                        var responseResult = caller->respond(<@untainted>providerHostResponse);

                        handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

                    } else {

                        setErrorProgresstrackingLog("Error: Creating IDS header for HeaderOnly response failed, no valid json IDSA header received", "dataInExtIntSHHO", closureProgress, createIDSHeaderResult);

                    }
                }

            } else {

                setErrorProgresstrackingLog("Error: Receiving SplitHeader gloProviderRestApiEndpoint response with StatusCode <= 299 failed, was: " + providerHostResponse.statusCode.toString() + " - " + providerHostResponse.reasonPhrase, "dataInExtIntSHHO", closureProgress);

            }

        } else {

            setErrorProgresstrackingLog("Error: Processing gloProviderRestApiEndpoint response failed, no valid HTTP received", "dataInExtIntSHHO", closureProgress, providerHostResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing gloProviderRestApiEndpoint response, error happened before");

    }

    // Sending error message back to external EIDS/IDS caller
    if (progress["errorBefore"] == true) {

        http:Response errorResponse = new;
        errorResponse.setPayload({"ErrorMessage": progress["errorMessage"]});
        errorResponse.statusCode = 500;

        var responseResult = caller->respond(errorResponse);

        handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

    } 
}