import ballerina/log;
import ballerina/file;
import ballerina/http;
import ballerina/mime;

function getInfo404(http:Caller caller, http:Request req) {

    // Delivering a simple HTML file as 404 info, other files should be hosted externally
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;

    if (file:exists("./data/404info.html")) {

        res.statusCode = 200;
        res.setFileAsPayload("./data/404info.html", contentType = mime:TEXT_HTML);
        log:printDebug("Success: Reading 404info.html");

    } else {

        progress["errorBefore"] = true;
        progress["errorMessage"] = "Error: Reading 404info.html failed, file not found";

        setResponseCodeTextLog(res, 404, progress["errorMessage"].toString(), "get404Info");
    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "getInfo404", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}