import ballerina/jwt;
import ballerina/log;
import ballerina/http;
import ballerina/mime;
import ballerina/time;
import ballerina/system;
import ballerina/crypto;
import ballerina/encoding;
import ballerina/lang.'int;
import ballerina/stringutils;


// KeyStore configuration to create the DAT request JWT
jwt:JwtKeyStoreConfig jwtKeyStoreConfig = {
    keyStore: {
        path: gloDapsKeyStoreInBallerinaRelativeFileInfo,
        password: gloDapsKeyStorePassword
    },
    keyAlias: gloDapsKeystorePrivateKeyAlias,
    keyPassword: gloDapsKeyStorePassword
};

// Validator configuration for AISEC DAPS DAT validator
jwt:JwtValidatorConfig validatorConfigDatDapsAISEC = {
    issuer: gloDatIssuer,
    // audience: gloDatAudience, // not yet stable in the current situation with only AISEC/Orbiter DAPS
    trustStoreConfig: {
        certificateAlias: gloDapsTrustStoreAlias,
        trustStore: gloTrustStoreBallerina
    },
    jwtCache: gloConnectorCache 
};

// Endpoint configuration for AISEC DAPS 
http:Client dapsEndpointDapsAISEC = new(gloDatEndpointUrl, gloStandardInfraStructureClientConfig);

// Endpoint configuration for Orbiter DAPS, currently no further Clientconfigurations, no HTTPS
http:Client dapsEndpointOrbiter = new(gloDatEndpointUrl);


function validateIncomingKeyRockToken(string incomingKeyRockToken, function (boolean, string) closureProgressError) returns string[]? {

    string[] roleArray = [];
    string appID = "";
    string appAzfDomain = "";
    int iat = 0;
    int exp = 0;
    int now = time:currentTime().time/1000;
    int nowPlusCacheMaxAgeSec = time:currentTime().time/1000 + gloIncTokenCacheMaxAgeSec;

    [jwt:JwtHeader, jwt:JwtPayload]|jwt:Error [header, payload] = jwt:decodeJwt(incomingKeyRockToken);
        
    // Extract the whole FIWARE KeyRock X-AUTH-TOKEN payload into a json object 
    map<json>? keyRockJWTTokenPayloadResult = payload["customClaims"];


    if (keyRockJWTTokenPayloadResult is map<json>) {

        // Extract the organisations element
        json[] orgArrayResult = <json[]>keyRockJWTTokenPayloadResult.organizations;

        foreach var org in orgArrayResult {

            json[] orgRoleArrayResult = <json[]>org.roles;

            // Extract all roles from each organizations element
            foreach var orgRoleId in orgRoleArrayResult {

                var orgRoleIdString = orgRoleId.id.toString();

                if (roleArray.indexOf(orgRoleIdString) is () && orgRoleIdString !="") {  

                    roleArray.push(orgRoleIdString);
                    log:printDebug("orgRoleId: " + orgRoleIdString + " extracted");

                }
            }
        }

        // Extract the roles element
        json[] userRoleArrayResult = <json[]>keyRockJWTTokenPayloadResult.roles;

        // Extracting all roles from each roles (userroles) element
        foreach var userRoleId in userRoleArrayResult {

            var userRoleIdString = userRoleId.id.toString();

            if (roleArray.indexOf(userRoleId.toString()) is () && userRoleIdString !="") {  

                roleArray.push(userRoleIdString);
                log:printDebug("userRoleId: " + userRoleIdString + " extracted");

            }
        }

        appID = <string>keyRockJWTTokenPayloadResult.app_id;
        appAzfDomain = <string>keyRockJWTTokenPayloadResult.app_azf_domain;

        int|error iatResult = 'int:fromString(<string>keyRockJWTTokenPayloadResult.iat);
        iat = iatResult is int ? iatResult : 0;

        int|error expResult = 'int:fromString(<string>keyRockJWTTokenPayloadResult.exp);
        exp = expResult is int ? expResult : 0;

        if (roleArray.length() > 0  && 
            appID === gloKeyRockAppID && 
            appAzfDomain === gloKeyRockAppAzfDomain) {

            if ((iat <= now) && (exp > nowPlusCacheMaxAgeSec)) {

                log:printDebug("Success: Validating FIWARE KeyRock X-AUTH-TOKEN, roles are available and all parameter (appID, appAzfDomain, iat, exp) are valid");

                error? cacheTokenResult = gloConnectorCache.put(<@untainted>incomingKeyRockToken, "validated");

                if (cacheTokenResult is ()) {

                    log:printDebug("Success: CACHE-PUT: Putting validated FIWARE KeyRock X-AUTH-TOKEN into Cache"); 

                } else {

                    log:printError("Error: Putting validated FIWARE KeyRock X-AUTH-TOKEN into Cache failed, process NOT halted, ongoing without cache, Token has been validated: ", cacheTokenResult); 

                }

                return roleArray;


            } else {

                setErrorProgresstrackingLog("Error: Validating FIWARE KeyRock X-AUTH-TOKEN failed, iat or exp (incl. CacheMaxAgeSec) invalid", "validateIncomingKeyRockToken", closureProgressError);

                return;

            }

        } else {

            setErrorProgresstrackingLog("Error: Validating FIWARE KeyRock X-AUTH-TOKEN failed, either no roles presented or invalid appID or invalid appAzfDomain", "validateIncomingKeyRockToken", closureProgressError);

            return;

        } 
        
    } else {

        setErrorProgresstrackingLog("Error: Validating FIWARE KeyRock X-AUTH-TOKEN failed, incoming token payload no valid json", "validateIncomingKeyRockToken", closureProgressError);

        return;

    }
} 


function validateIncomingKeyRockTokenSignature(string incomingKeyRockToken, function (boolean, string) closureProgressError) returns boolean {

    if (gloConnectorCache.hasKey(incomingKeyRockToken)) {

        log:printDebug("Success: CACHE-HIT: FIWARE KeyRock X-AUTH-TOKEN validated from Cache, no signature validation needed");

        return true;

    } else {

        string[] jwtSplits = stringutils:split(incomingKeyRockToken, "\\.");    

        if (jwtSplits.length() != 3) {

            setErrorProgresstrackingLog("Error: Validating Validating FIWARE KeyRock X-AUTH-TOKEN signature failed, no valid JWT received", "validateIncomingKeyRockTokenSignature", closureProgressError);

            return false;

        }

        string headerPayloadConcat = jwtSplits[0] + "." + jwtSplits[1]; 

        byte[] data = headerPayloadConcat.toBytes();
        byte[] key = gloKeyRockSH256Secret.toBytes();
        byte[] hmac = crypto:hmacSha256(data, key);
        string counterSignature = encoding:encodeBase64Url(hmac);

        if (counterSignature === jwtSplits[2]) {

            return false;

        } else {

            setErrorProgresstrackingLog("Error: Validating Validating FIWARE KeyRock X-AUTH-TOKEN signature failed", "validateIncomingKeyRockTokenSignature", closureProgressError);

            return false;

        }
    }
} 


function validateIncomingDatToken(string incomingDatToken, function (boolean, string) closureProgressError) {

    // First steps for Multi-Daps Validation, currently only AISEC and Orbiter, one at a time, to be decided BEFORE installation

    // AISEC DAPS
    if (gloDatDapsName == "AISEC") {

        log:printDebug("Success: Extracting incoming DAT JWT, ready for AISEC DAPS validation: " + incomingDatToken);

        jwt:JwtPayload|jwt:Error validateJWTResult = jwt:validateJwt(incomingDatToken, validatorConfigDatDapsAISEC);

        if (validateJWTResult is error) {

            setErrorProgresstrackingLog("Error: Validating incoming AISEC DAT JWT failed, ", "validateIncomingDatToken", closureProgressError, validateJWTResult);
        }

        return;

    // Orbiter DAPS
    } else if (gloDatDapsName == "Orbiter") {

        log:printDebug("Success: Extracting incoming DAT JWT, ready for Orbiter DAPS validation: " + incomingDatToken);

        if (gloConnectorCache.hasKey(incomingDatToken)) {
    
            log:printDebug("Success: CACHE-HIT: Orbiter DAT JWT validated with existing cache item");

            return;

        } else {

            json datValidationRequestJsonPayload = {
                "token": incomingDatToken
            };

            http:Request datValidationRequest = new;
            json datValidationJsonResponse = {};

            datValidationRequest.setJsonPayload(datValidationRequestJsonPayload, contentType = mime:APPLICATION_JSON);

            // Receiving DAT JWT validation response from Orbiter DAPS ... currently only HTTP, NO HTTPS
            var getDatValidationRequestResult = dapsEndpointOrbiter->post(gloDatEndpointPath + "/validate", datValidationRequest);

            if (getDatValidationRequestResult is http:Response) {

                if (getDatValidationRequestResult.statusCode == 200){    

                    var getDatValidationResponseJsonPayloadResult = getDatValidationRequestResult.getJsonPayload();
                    var getDatValidationResponseContentTypeResult = getDatValidationRequestResult.getContentType();

                    log:printDebug(getDatValidationResponseContentTypeResult); 

                    if (getDatValidationResponseJsonPayloadResult is json) {

                        datValidationJsonResponse = getDatValidationResponseJsonPayloadResult;
                        log:printDebug("Success: Receiving DAT JWT validation json response from Orbiter DAPS with StatusCode 200"); 

                    } else if (getDatValidationResponseContentTypeResult == "text/html; charset=utf-8") {

                        var getDatValidationResponseTextPayloadResult = getDatValidationRequestResult.getTextPayload();

                        if (getDatValidationResponseTextPayloadResult is string) {

                            setErrorProgresstrackingLog("Error: Receiving DAT JWT validation from Orbiter DAPS failed, no mandatory -Token successfully validated- json payload received, ", "validateIncomingDatToken", closureProgressError, getDatValidationResponseTextPayloadResult);

                            return;
    
                        } else {

                            setErrorProgresstrackingLog("Error: Receiving DAT JWT validation from Orbiter DAPS failed, no mandatory -Token successfully validated- json payload received, ", "validateIncomingDatToken", closureProgressError);

                            return;

                        }


                    } else {

                        setErrorProgresstrackingLog("Error: Receiving DAT JWT validation response from Orbiter DAPS failed, no valid json or text payload received, ", "validateIncomingDatToken", closureProgressError);

                        return;

                    }

                } else {

                    setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT validation response from Orbiter DAPS failed, no StatusCode 200", "validateIncomingDatToken", closureProgressError);
                    
                    return;

                }

            } else {

                setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT validation response from Orbiter DAPS failed, no valid HTTP response, ", "validateIncomingDatToken", closureProgressError, getDatValidationRequestResult);

                return;
                
            }

            // Processing Dat JWT validation rsponse and checking positive validation
            if (datValidationJsonResponse.response is json) {

                if (datValidationJsonResponse.response == true && 
                    datValidationJsonResponse.description == "Token successfully validated") {

                    error? cacheTokenResult = gloConnectorCache.put(incomingDatToken, "validated");

                    if (cacheTokenResult is ()) {

                        log:printDebug("Success: CACHE-HIT: Validated DAT JWT from Orbiter DAPS and put into cache"); 

                    } else {

                        log:printDebug("Info: DAT JWT from Orbiter DAPS got validated but could not be put into Cache, processing goes on");

                    }

                    return;

                } else {

                    setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT validation response from Orbiter DAPS failed, payload json elements (response == true and description == 'Token successfully validated') not received", "validateIncomingDatToken", closureProgressError);

                    return;

                }

            } else {

                setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT validation response from DAPS failed, no respone json element in JSON DAT validation response", "createGlobalDatToken", closureProgressError);

                return;

            }
        }
    }
}   


function provideGlobalDatToken(function (boolean, string) closureProgressError) {

    // Checking whether former DAT JWT is globally available and internally valid > 2 min, else creat a new one
    if (gloDatTokenJWT != "" && ( gloDatTokenInternValidEndTime - time:currentTime().time/1000 > 120)) {

        log:printDebug("Info: Skipping obtaining DatTokenJWT, former DAPSTokenJWT for current DAPS " + gloDatDapsName + " still valid > 2 min");

        return;

    }

    createGlobalDatToken(closureProgressError);

    return;

}


// A new DAT JWT from DAPS will only be created if there is no former DAT JWT saved globally or an existing DAT JWT is  internally valid < 2min 
function createGlobalDatToken(function (boolean, string) closureProgressError) {

    string datRequestJWT = "";

    // AISEC DAPS
    if (gloDatDapsName == "AISEC") {

        jwt:JwtHeader headerJSON = {
            "alg": "RS256",
            "typ": "JWT"
        };

        jwt:JwtPayload payloadJSON = {
            "iss": gloX509SKIAKI,
            "sub": gloX509SKIAKI,
            "aud": ["idsc:IDS_CONNECTORS_ALL"],
            "exp": time:currentTime().time/1000 + 60,
            "iat": time:currentTime().time/1000,
            "nbf": time:currentTime().time/1000,
            customClaims: {
                "@context": "https://w3id.org/idsa/contexts/context.jsonld",
                "@type": "ids:DatRequestToken"
            }
        };

        string|jwt:Error jwtResult = jwt:issueJwt(headerJSON, payloadJSON, jwtKeyStoreConfig);

        if (jwtResult is string) {

            datRequestJWT = jwtResult;
      
        } else {

            setErrorProgresstrackingLog("Error: Creating AISEC DAT request JWT, ", "createGlobalDatToken", closureProgressError, jwtResult);

            return;

        }

        // Creating the form-url encoded request payload for the AISEC DAT JWT request call
        string textPayload = "grant_type=client_credentials";
        textPayload += "&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer";
        textPayload += "&client_assertion=" + datRequestJWT;
        textPayload += "&scope=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL";

        // Creating the request for the AISEC DAT JWT request call
        http:Request datTokenRequest = new;
        json datTokenResponseJson = {};

        datTokenRequest.setTextPayload(textPayload, contentType = mime:APPLICATION_FORM_URLENCODED);

        // Receiving DAT JWT response from AISEC DAPS
        var getDatTokenResponseResult = dapsEndpointDapsAISEC->post(gloDatEndpointPath, datTokenRequest);

        if (getDatTokenResponseResult is http:Response) {

            if (getDatTokenResponseResult.statusCode == 200) {    

                var getDatTokenResponsePayloadResult = getDatTokenResponseResult.getJsonPayload();

                if (getDatTokenResponsePayloadResult is json) {

                    datTokenResponseJson = getDatTokenResponsePayloadResult;
                    log:printDebug("Success: Receiving DAT JWT response from AISEC DAPS with StatusCode 200"); 

                } else {

                    setErrorProgresstrackingLog("Error: Receiving DAT JWT response from AISEC DAPS failed, no valid json payload", "createGlobalDatToken", closureProgressError);

                    return;

                }

            } else {

                setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT response from AISEC DAPS failed, no StatusCode 200", "createGlobalDatToken", closureProgressError);

                return;

            }

        } else {

            setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT response from AISEC DAPS failed, no valid HTTP Response, ", "createGlobalDatToken", closureProgressError, getDatTokenResponseResult);

            return;

        } 

        // Processing DAT JWT response from AISEC DAPS
        if (datTokenResponseJson.access_token is json) {

            gloDatTokenJWT = <@untainted>datTokenResponseJson.access_token.toString();
            gloDatTokenInternValidEndTime = time:currentTime().time/1000 + gloDatTokenInternValidAddOnSeconds;
            gloDatTokenJWTID = system:uuid(); 
            log:printDebug("Success: Creating AISEC DAT JWT: " + gloDatTokenJWT + " with DAT JWT ID: " + gloDatTokenJWTID); 
            log:printDebug("Success: Creating AISEC DAT JWT ValidTime: " + gloDatTokenInternValidEndTime.toString()); 

            return;

        } else {

            setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT response from AISEC DAPS failed, no access_token element in json DAT JWT response", "createGlobalDatToken", closureProgressError);

            return;

        }

    } else if (gloDatDapsName == "Orbiter") {

        jwt:JwtHeader headerJSON = {
            "alg": "RS256",
            "typ": "JWT"
        };

        jwt:JwtPayload payloadJSON = {
            customClaims: {
                "id": gloConnectorID
            }
        };

        string|jwt:Error jwtResult = jwt:issueJwt(headerJSON, payloadJSON, jwtKeyStoreConfig);

        if (jwtResult is string) {

            datRequestJWT = jwtResult;
      
        } else {

            setErrorProgresstrackingLog("Error: Creating Orbiter DAT request JWT, ", "createGlobalDatToken", closureProgressError, jwtResult);

            return;

        }
    
        // Creating the json request payload for the Orbiter DAT JWT request call
        json datRequestCallJsonPayload = {
            "client_assertion": datRequestJWT,
            "client_assertion_type": "jwt-bearer",
            "scope": "all",
            "grant_type": "client_credentials"
        };

        // Creating the request for the Orbiter DAT JWT request call
        http:Request datTokenRequest = new;
        json datTokenResponseJson = {};

        datTokenRequest.setJsonPayload(datRequestCallJsonPayload);

        // Receiving DAT JWT response from Orbiter DAPS
        var getDatTokenResponseResult = dapsEndpointOrbiter->post("/token", datTokenRequest);

        if (getDatTokenResponseResult is http:Response) {

            if (getDatTokenResponseResult.statusCode == 200) {

                var getDatTokenResponsePayloadResult = getDatTokenResponseResult.getJsonPayload();

                if (getDatTokenResponsePayloadResult is json) {

                    datTokenResponseJson = getDatTokenResponsePayloadResult;
                    log:printDebug("Success: Receiving DAT JWT response from Orbiter DAPS with StatusCode 200"); 

                } else {

                    setErrorProgresstrackingLog("Error: Receiving DAT JWT response from Orbiter DAPS failed, no valid json payload received", "createGlobalDatToken", closureProgressError);

                    return;

                }

            } else {

                setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT from Orbiter DAPS failed, no StatusCode 200", "createGlobalDatToken", closureProgressError);

                return;
            }

        } else {

            setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT from Orbiter DAPS failed, no valid HTTP Response, ", "createGlobalDatToken", closureProgressError, getDatTokenResponseResult);

            return;

        } 

        // Processing DAT JWT response from Orbiter DAPS
        if (datTokenResponseJson.response is json) {

            gloDatTokenJWT = <@untainted>datTokenResponseJson.response.toString();
            gloDatTokenInternValidEndTime = time:currentTime().time/1000 + gloDatTokenInternValidAddOnSeconds;
            gloDatTokenJWTID = system:uuid(); 
            log:printDebug("Success: Creating Orbiter DAT JWT: " + gloDatTokenJWT + " with DAT JWT ID: " + gloDatTokenJWTID); 
            log:printDebug("Success: Creating Orbiter DAT JWT ValidTime: " + gloDatTokenInternValidEndTime.toString()); 

            return;

        }

        else {

            setErrorProgresstrackingLog("Error: Invoking call and receiving DAT JWT from Orbiter DAPS failed, no response element in json DAT JWT response", "createGlobalDatToken", closureProgressError);

            return;

        }
    }
}