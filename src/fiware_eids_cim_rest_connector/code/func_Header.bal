import ballerina/log;
import ballerina/http;
import ballerina/time;
import ballerina/system;


function addSHHeader(http:Request req, string requestMessageType, string messageUUID, string messageTime, string locDatTokenJWT, string additionalHeaderKey, string additionalHeaderValue, string fiwareService, string fiwareServicePath) returns http:Request {  

    // Adding IDS SplitHeader header to request object
    req.addHeader("IDS-Messagetype", requestMessageType);
    req.addHeader("IDS-Id","https://industrialdataspace.org/RequestMessage/"+ messageUUID); 
    req.addHeader("IDS-Issued", messageTime);
    req.addHeader("IDS-ModelVersion", gloIDSInfoModelVersionOutgoing);
    req.addHeader("IDS-IssuerConnector","https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath);
    req.addHeader("IDS-SecurityToken-Type","ids:DynamicAttributeToken");
    req.addHeader("IDS-SecurityToken-TokenFormat","https://w3id.org/idsa/code/tokenformat/JWT");
    req.addHeader("IDS-SecurityToken-TokenValue",locDatTokenJWT);
    req.addHeader("IDS-CorrelationMessage","https://www.notimplementedyet.com");
    req.addHeader("IDS-TransferContract","https://www.notimplementedyet.com");
 
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

    log:printDebug("Success: Setting IDS SplitHeader Header");

    return req;

}


function createIDSHeader(string messageType) returns @untainted json {

    string messageID = "https://w3id.org/idsa/autogen/" + messageType.substring(4).toLowerAscii() + "/" + system:uuid();

    // Creating the IDS header, as described in IDSA Communication Guide, dated September 2020
    json idsHeader = {
        "@context" : {
            "ids" : "https://w3id.org/idsa/core/",
            "idsc" : "https://w3id.org/idsa/code/"
        },
        "@type" : messageType,
        "@id" : messageID,
        "ids:securityToken" : {
            "@type" : "ids:DynamicAttributeToken",
            "@id" : "https://w3id.org/idsa/autogen/dynamicAttributeToken/" + gloDatTokenJWTID,
            "ids:tokenValue" : gloDatTokenJWT,
            "ids:tokenFormat" : {
                "@id" : "idsc:JWT"
            }
        },
        "ids:senderAgent" : {
            "@id" : "https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath
        },
        "ids:issuerConnector" : {
            "@id" : "https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath
        },
        "ids:issued" : {
            "@value" : time:toString(time:currentTime()),
            "@type" : "http://www.w3.org/2001/XMLSchema#dateTimeStamp"
        },
        "ids:modelVersion" : gloIDSInfoModelVersionOutgoing,
        "ids:affectedConnector" : {
            "@id" : "https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath
        },
        "ids:correlationMessage" : {
            "@id" : "not implemented, currently for completeness reasons"
        }

    };
                
    return idsHeader;

}