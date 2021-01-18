import ballerina/log;
import ballerina/file;
import ballerina/http;
import ballerina/mime;

function getConnectorInfo(http:Caller caller, http:Request req) {

    // Delivering a simple HTML file as extended connector description, other files should be hosted externally
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;

    if (file:exists("./data/connectorinfo.html")) {

        res.statusCode = 200;
        res.setFileAsPayload("./data/connectorinfo.html", contentType = mime:TEXT_HTML);
        log:printDebug("Success: Reading connectorinfo.html");

    } else {

        progress["errorBefore"] = true;
        progress["errorMessage"] = "Error: Reading connectorinfo.html failed, file not found";
        setResponseCodeTextLog(res, 404, progress["errorMessage"].toString(), "getConnectorInfo");

    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "getConnectorInfo", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());
}