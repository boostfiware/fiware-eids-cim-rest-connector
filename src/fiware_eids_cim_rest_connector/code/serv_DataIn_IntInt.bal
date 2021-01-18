import ballerina/log;
import ballerina/http;
import ballerina/stringutils;


function dataInInternalInternal(http:Caller caller, http:Request req, int serviceCallTimeNano) {

    int lastServiceTimeStampNano = serviceCallTimeNano;
    string userPath = "";
    http:Response|error providerHostResponse = new;
    string abbrServiceName = "intInt";    

    // Setting ProgressErrorTracking with closure
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };
    var closureProgress = function (boolean errorB, string errorM) {
        progress["errorBefore"] = errorB;
        progress["errorMessage"] = errorM;
    };

    // Extracting relevant infos from incoming internal call
    userPath = req.rawPath.substring(gloDataRootLength);

    // Validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorization, if activated
    if (gloKeyRockActivationIntInt) {

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

            setErrorProgresstrackingLog("Error: Validating FIWARE KeyRock X-AUTH-TOKEN JWT 3-part-structure failed, no valid JWT received, or the mandatory header Fiware-Service was missing", "dataInIntIntSHHO", closureProgress);

        }

        // Validating FIWARE KeyRock X-AUTH-TOKEN JWT signature
        if (progress["errorBefore"] == false) {

            log:printDebug("Validating FIWARE KeyRock X-AUTH-TOKEN JWT 3-part-structure and existance of a Fiware-Service header/value");

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

    if (gloLogLevelNotOffOrError) {

        lastServiceTimeStampNano = logNanoTimeStampsLogLevelWARN("03", abbrServiceName, "Validating KeyRock JWT and authorization", serviceCallTimeNano, lastServiceTimeStampNano);

    }

    // Calling gloProviderRestApiEndpoint forwarding request and receiving response
    if (progress["errorBefore"] == false) {

        log:printDebug("Success: Validating FIWARE KeyRock X-AUTH-TOKEN JWT and authorizaton");

        // Forwarding request to gloProviderRestApiEndpoint/userPath
        providerHostResponse = gloProviderRestApiEndpoint->forward(<@untainted>userPath, req);

    } else {    

        log:printDebug("Info: Skipping calling gloProviderRestApiEndpoint forwarding request and receiving response, error happened before");

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

                var responseResult = caller->respond(<@untainted>providerHostResponse);

                handleResponseResult(responseResult, abbrServiceName, serviceCallTimeNano, lastServiceTimeStampNano, progress["errorBefore"], progress["errorMessage"].toString());

            } else {

                setErrorProgresstrackingLog("Error: Receiving gloProviderRestApiEndpoint response with StatusCode <= 299 failed, was: " + providerHostResponse.statusCode.toString() + " - " + providerHostResponse.reasonPhrase, "dataInIntIntSHHO", closureProgress);

            }

        } else {

            setErrorProgresstrackingLog("Error: Processing gloProviderRestApiEndpoint response failed, no valid HTTP received", "dataInIntIntSHHO", closureProgress, providerHostResponse);

        }

    } else {

        log:printDebug("Info: Skipping processing gloProviderRestApiEndpoint response, error happened before");

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