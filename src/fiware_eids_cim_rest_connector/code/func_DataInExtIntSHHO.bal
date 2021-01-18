import ballerina/log;
import ballerina/http;

function addSHResponseHeader(http:Response res, string responseMessageType, string messageUUID, string messageTime, string locDatTokenJWT) returns http:Response {  

    // Adding IDS SplitHeader header to response object
    res.addHeader("IDS-Messagetype", responseMessageType);
    res.addHeader("IDS-Id","http://industrialdataspace.org/ResponseMessage/"+ messageUUID);
    res.addHeader("IDS-Issued", messageTime);
    res.addHeader("IDS-ModelVersion", gloIDSInfoModelVersionOutgoing);
    res.addHeader("IDS-IssuerConnector","https://" + gloIngressHostNameFQN + gloIngressHostNameFQNPort + gloBasePath);
    res.addHeader("IDS-SecurityToken-Type","ids:DynamicAttributeToken");
    res.addHeader("IDS-SecurityToken-TokenFormat","https://w3id.org/idsa/code/tokenformat/JWT");
    res.addHeader("IDS-SecurityToken-TokenValue",locDatTokenJWT);
    res.addHeader("IDS-CorrelationMessage","https://www.notimplementedyet.com");
    res.addHeader("IDS-TransferContract","https://www.notimplementedyet.com");

    log:printDebug("Success: Setting IDS SplitHeader header");

    return res;

}