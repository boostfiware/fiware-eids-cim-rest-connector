import ballerina/log;
import ballerina/http;
import ballerina/lang.'xml as xmllib;


// Endpoint configuration for XACML Endpoint - CertCheck DISABLED
http:Client xacmlEndpointAuthZForce = new(gloXacmlEndpointUrl, gloStandardInfraStructureClientConfig);

function checkXACMLAuthorization(string authZForceCacheKey, string method, string path, string fiwareService, string issDapsURL, string[] roleStringArray, function (boolean, string) closureProgressError) {

    xml xmlRoleAttributeValues = xml `<Request>Just for for initialization purposes</Request>`;
    int counter = 0;

    // Constructing set of AttributeValues for each of the roles in roleArray
    foreach var role in roleStringArray {
        
        if (counter == 0) {
        
            xmlRoleAttributeValues = xml `<AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${role}</AttributeValue>`;

        } else {

            xmlRoleAttributeValues = xmllib:concat(xmlRoleAttributeValues, xml `<AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${role}</AttributeValue>`);

        }

        counter += 1;

    }

    // Constructing the attributes of category attribute-category:action
    xml xmlCatAction = xml `<Attributes Category="urn:oasis:names:tc:xacml:3.0:attribute-category:action">
        <Attribute AttributeId="urn:oasis:names:tc:xacml:1.0:action:action-id" IncludeInResult="false">
            <AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${method}</AttributeValue>
        </Attribute>
    </Attributes>`;

    // Constructing the attributes of category attribute-category:resource
    xml xmlCatResource = xml `<Attributes Category="urn:oasis:names:tc:xacml:3.0:attribute-category:resource">
        <Attribute AttributeId="urn:oasis:names:tc:xacml:1.0:resource:resource-id" IncludeInResult="false">
            <AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${gloKeyRockAppID}</AttributeValue>
        </Attribute>
        <Attribute AttributeId="urn:thales:xacml:2.0:resource:sub-resource-id" IncludeInResult="false">
            <AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${path}</AttributeValue>
        </Attribute>
        <Attribute AttributeId="urn:thales:xacml:2.0:resource:fiware-service" IncludeInResult="false">
            <AttributeValue DataType="http://www.w3.org/2001/XMLSchema#string">${fiwareService}</AttributeValue>
        </Attribute>
        <Attribute AttributeId="urn:thales:xacml:2.0:resource:daps-service" IncludeInResult="false">
            <AttributeValue DataType="http://www.w3.org/2001/XMLSchema#anyURI">${issDapsURL}</AttributeValue>
        </Attribute>
    </Attributes>`;

    // Constructing the attributes of category :access-subject
    xml xmlCatAccessSubject = xml `<Attributes Category="urn:oasis:names:tc:xacml:1.0:subject-category:access-subject">
        <Attribute AttributeId="urn:oasis:names:tc:xacml:2.0:subject:role" IncludeInResult="false">
            ${xmlRoleAttributeValues}
        </Attribute>
    </Attributes>`;

    // Combining all attributes into the finalRequestXML
    xml finalRequestXML = xml `<Request xmlns="urn:oasis:names:tc:xacml:3.0:core:schema:wd-17" CombinedDecision="false" ReturnPolicyIdList="false">
        ${xmlCatAction}
        ${xmlCatResource}
        ${xmlCatAccessSubject}
    </Request>`;

    // Send the finalRequestXML to AuthZForce PDP endpoint
    var responseResult = xacmlEndpointAuthZForce->post("/pdp", <@untainted> finalRequestXML);

    if (responseResult is http:Response) {

        var responsePayload = responseResult.getXmlPayload();

        if (responsePayload is xml) {

            log:printDebug(responsePayload.toString());

            if (responsePayload.toString().indexOf("Permit") is int) {

                log:printDebug("Success: PERMIT: AuthZForce authorization request has been permitted");

                error? cacheTokenResult = gloConnectorCache.put(authZForceCacheKey, "validated");

                if (cacheTokenResult is ()) {

                    log:printDebug("Success: CACHE-PUT: Putting concatenated request string for cache handling into cache"); 

                } else {

                    log:printError("Error: Putting concatenated request string into cache failed, process NOT halted, ongoing without cache, token has been validated: ", cacheTokenResult);

                }

                return;

            } else {

                setErrorProgresstrackingLog("Error: DENY: Checking KeyRock authorization failed, request has been denied", "checkXACMLAuthorization", closureProgressError);

                return;

            }

        } else {

            setErrorProgresstrackingLog("Error: Checking KeyRock authorization failed, no valid XML response", "checkXACMLAuthorization", closureProgressError);

            return;

        }

    } else {

            setErrorProgresstrackingLog("Error: Checking KeyRock authorization failed, no valid HTTP response, ", "checkXACMLAuthorization", closureProgressError, responseResult);

            return;

    }
}
