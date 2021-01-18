import ballerina/file;
import ballerina/http;


function postSelfDescription(http:Caller caller, http:Request req) {     

    // Creating a selfdescription.json file from POST payload
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;

    var selfDescriptionJson = req.getJsonPayload();
    boolean fileExisted = file:exists(gloFilePathSelfDesriptionInBallerina);

    if (selfDescriptionJson is json && !fileExisted) {

        var writeFileResult = writeFile(selfDescriptionJson, gloFilePathSelfDesriptionInBallerina);

        if (writeFileResult is error) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Creating the selfdescription.json failed";

            setResponseCodeTextLog(res, 500, progress["errorMessage"].toString(), "postSelfDescription", writeFileResult);

        } else {

            setResponseCodeTextLog(res, 201, "Success: Creating the selfdescription.json", "postSelfDescription");

        }

    } else {

        if (fileExisted) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Creating the selfdescription.json failed, conflict: already existed, please delete before POST";

            setResponseCodeTextLog(res, 409, progress["errorMessage"].toString(), "postSelfDescription");

        } else {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Creating the selfdescription.json failed, payload is no valid JSON";

            setResponseCodeTextLog(res, 400, progress["errorMessage"].toString(), "postSelfDescription");

        }
    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "postSelfDescription", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}


function putSelfDescription(http:Caller caller, http:Request req) {

    // Updating an existing selfdescription.json file from PUT payload
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;

    var selfDescriptionJson = req.getJsonPayload();
    boolean fileExisted = file:exists(gloFilePathSelfDesriptionInBallerina);
    file:Error? removeResult = file:remove(gloFilePathSelfDesriptionInBallerina);

    if (selfDescriptionJson is json && fileExisted && !(removeResult is error)) {

        var writeFileResult = writeFile(selfDescriptionJson, gloFilePathSelfDesriptionInBallerina);

        if (writeFileResult is error) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Updating new selfdescription.json failed";

            setResponseCodeTextLog(res, 500, progress["errorMessage"].toString(), "putSelfDescription", writeFileResult);

        } else {

            setResponseCodeTextLog(res, 201, "Success: Updating new selfdescription.json", "putSelfDescription");

        }

    } else {

        if (!fileExisted) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Updating new selfdescription.json failed, conflict: selfdescription.json not existed to update";

            setResponseCodeTextLog(res, 409, progress["errorMessage"].toString(), "putSelfDescription");

        } else if (removeResult is error) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Updating new selfdescription.json failed, removing former selfdescription.json failed";

            setResponseCodeTextLog(res, 500, progress["errorMessage"].toString(), "putSelfDescription");

        } else {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Updating new selfdescription.json failed, payload is no valid json";

            setResponseCodeTextLog(res, 400, progress["errorMessage"].toString(), "putSelfDescription");

        }
    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "putSelfDescription", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}


function deleteSelfDescription(http:Caller caller, http:Request req) {

    // Deleting an existing selfdescription.json File
    string errorMessage = "";
    map<json> progress = {errorBefore: false, errorMessage: errorMessage };

    http:Response res = new;
    
    boolean fileExisted = file:exists(gloFilePathSelfDesriptionInBallerina);
    file:Error? removeResult = file:remove(gloFilePathSelfDesriptionInBallerina);

    if (fileExisted && !(removeResult is error)) {

        setResponseCodeTextLog(res, 200, "Success: Deleting selfdescription.json", "deleteSelfDescription");

    } else {

        if (!fileExisted) {

            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Deleting selfdescription.json failed, file not found/existed";

            setResponseCodeTextLog(res, 404, progress["errorMessage"].toString(), "deleteSelfDescription");

        } else {


            progress["errorBefore"] = true;
            progress["errorMessage"] = "Error: Deleting selfdescription.json failed, removing former selfdescription.json failed";

            setResponseCodeTextLog(res, 500, progress["errorMessage"].toString(), "deleteSelfDescription");

        }
    }

    var responseResult = caller->respond(res);

    handleResponseResult(responseResult, "deleteSelfDescription", 0, 0, progress["errorBefore"], progress["errorMessage"].toString());

}


function readFileSelfDescriptionJsonLd() returns @untainted json|error {

    // Reading in the selfdescription.json file
    json readFileResult = check readFile(gloFilePathSelfDesriptionInBallerina);

    return readFileResult;

}