import ballerina/io;
import ballerina/log;
import ballerina/http;
import ballerina/time;


function logNanoTimeStampsLogLevelWARN(string logCode, string abbrServiceName, string logText, int serviceCallTimeNano, int lastServiceTimeStampNano) returns int {

    int nowNanoTime = time:nanoTime();

    if (serviceCallTimeNano != 0 && lastServiceTimeStampNano != 0) {

        int deltaServiceCallTimeNano = (nowNanoTime - serviceCallTimeNano) / 1000000;
        int deltaLastServiceTimeStampNano = (nowNanoTime - lastServiceTimeStampNano) / 1000000;

        if (deltaLastServiceTimeStampNano > 50 || (logCode == "VV" && deltaServiceCallTimeNano > 100)){

            log:printWarn("LR:" + logCode + ", ms: " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " step, " + io:sprintf("%04d", deltaServiceCallTimeNano) + " total, " + abbrServiceName + ", " + logText);

        } 

    } 

    return nowNanoTime;

}


function setErrorProgresstrackingLog(string errorMessage, string errorFunctionOccured, function (boolean, string) closureProgressError, string|error? err = "") {

    if (err is error) {

        log:printError(errorMessage + " in: " + errorFunctionOccured + " - ", err);
        closureProgressError(true, errorMessage + " - " + err.reason() + " - " + err.detail().toString());

    } else {

        log:printError(errorMessage + " - occured in function: " + errorFunctionOccured);
        closureProgressError(true, errorMessage);

    }
}


function setResponseCodeTextLog(http:Response res, int code, string messageText, string errorFunctionOccured, string|error? err = "n.a.") {

    // Logging the error messages to the response payloads and also to the console
    res.statusCode = code;

    if (err is error) {

        res.setJsonPayload({"Message": messageText});
        log:printError("Error: Invoking operation failed, StatusCode: " + code.toString() + " occurred in unction: " + errorFunctionOccured + ", Error: " + messageText, err);

    } else if (code <= 299) {

        res.setJsonPayload({"Message": messageText});
        log:printDebug("Success: Invoking operation, StatusCode: " + code.toString() + ", Success: " + messageText);

    } else {

        res.setJsonPayload({"Message": messageText});
        log:printError("Error: Invoking operation failed, StatusCode: " + code.toString() + " occurred in Function: " + errorFunctionOccured + " - " + messageText + " - no error attached");

    }
}


function handleResponseResult(error? responseResult, string abbrServiceName, int serviceCallTimeNano, int lastServiceTimeStampNano, json errorBefore, string errorMessage) {
    
    int nowNanoTime = time:nanoTime();
    int deltaServiceCallTimeNano = (nowNanoTime - serviceCallTimeNano) / 1000000;
    int deltaLastServiceTimeStampNano = (nowNanoTime - lastServiceTimeStampNano) / 1000000;

    if (responseResult is error) {

        if (errorBefore == true) {

            if (abbrServiceName == "extInt") {

                gloCounterDataInExtIntSHHOFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInExtIntSHHOFailure.toString() + " - SplitHeader/HeaderOnly request to gloProviderRestApiEndpoint failed. Error message could not be sent to external caller. - " + errorMessage);

                

            } else if (abbrServiceName == "intExt") {

                gloCounterDataInIntExtSHFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntExtSHFailure.toString() + " - SplitHeader request to externalProviderHostURL failed. Error message could not be sent to internal caller. - " + errorMessage);

            } else if (abbrServiceName == "intInt") {

                gloCounterDataInIntIntFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntIntFailure.toString() + " - Internal request to gloProviderRestApiEndpoint failed. Error message could not be sent to internal caller. - " + errorMessage);
            
            } else {

                gloCounterDiverseFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDiverseFailure.toString() + " - One of the single-transcation service requests failed. Error message could not be sent to external caller. - " + errorMessage);

            }

        } else {

            if (abbrServiceName == "extInt") {

                gloCounterDataInExtIntSHHOFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInExtIntSHHOFailure.toString() + " - Response from gloProviderRestApiEndpoint received but could not be sent back to external caller. - " + errorMessage);

            } else if (abbrServiceName == "intExt") {

                gloCounterDataInIntExtSHFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntExtSHFailure.toString() + " - Response from externalProviderHostURL received but could not be sent back to internal caller. - " + errorMessage);

            } else if (abbrServiceName == "intInt") {

                gloCounterDataInIntIntFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntIntFailure.toString() + " - Response from gloProviderRestApiEndpoint received but could not be sent back to internal caller. - " + errorMessage);
            
            } else {

                gloCounterDiverseFailure += 1;

                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDiverseFailure.toString() + " - Response from one of the single-transcation service but could not be sent back to external caller. - " + errorMessage);

            }

        }

    } else {

        if (errorBefore == true) {

            if (abbrServiceName == "extInt") {

                gloCounterDataInExtIntSHHOFailure += 1;
                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInExtIntSHHOFailure.toString() + " - SplitHeader/HeaderOnly request to gloProviderRestApiEndpoint failed. Error message was sent to external caller. - " + errorMessage);


            } else if (abbrServiceName == "intExt") {

                gloCounterDataInIntExtSHFailure += 1;
                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntExtSHFailure.toString() + " - SplitHeader request to externalProviderHostURL failed. Error message was sent to internal caller. - " + errorMessage);


            } else if (abbrServiceName == "intInt") {

                gloCounterDataInIntIntFailure += 1;
                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDataInIntIntFailure.toString() + " - Internal request to gloProviderRestApiEndpoint failed. Error message was sent to internal caller. - " + errorMessage);

            
            } else {

                gloCounterDiverseFailure += 1;
                log:printError("Error: XX - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, FC for service: " + abbrServiceName + " is: " + gloCounterDiverseFailure.toString() + " - One of the single-transcation service requests failed. Error message was sent to external caller. - " + errorMessage);

            }

        } else {

            if (abbrServiceName == "extInt") {

                gloCounterDataInExtIntSHHOSuccess += 1;
                log:printDebug("Success: VV - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, SC for service: " + abbrServiceName + " is: " + gloCounterDataInExtIntSHHOSuccess.toString() + " - Response from gloProviderRestApiEndpoint received and sent back to external caller.");

                if (gloCounterDataInExtIntSHHOSuccess % 1000 == 0) {

                    log:printWarn("Success: SCounter " + abbrServiceName + " passed 1000s: " + gloCounterDataInExtIntSHHOSuccess.toString());

                }


            } else if (abbrServiceName == "intExt") {

                gloCounterDataInIntExtSHSuccess += 1;
                log:printDebug("Success: VV - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, SC for service: " + abbrServiceName + " is: " + gloCounterDataInIntExtSHSuccess.toString() + " - Response from externalProviderHostURL received but and sent back to internal caller.");

                if (gloCounterDataInIntExtSHSuccess % 1000 == 0) {

                    log:printWarn("Success: SCounter " + abbrServiceName + " passed 1000s: " + gloCounterDataInIntExtSHSuccess.toString());

                }

            } else if (abbrServiceName == "intInt") {

                gloCounterDataInIntIntSuccess += 1;
                log:printDebug("Success: VV - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, SC for service: " + abbrServiceName + " is: " + gloCounterDataInIntIntSuccess.toString() + " - Response from gloProviderRestApiEndpoint received but and be sent back to internal caller.");

                if (gloCounterDataInIntIntSuccess % 1000 == 0) {

                    log:printWarn("Success: SCounter " + abbrServiceName + " passed 1000s: " + gloCounterDataInIntIntSuccess.toString());

                }
            
            } else {

                gloCounterDiverseSuccess += 1;
                log:printDebug("Success: VV - " + io:sprintf("%04d", deltaLastServiceTimeStampNano) + " ms/step - " + io:sprintf("%04d", deltaServiceCallTimeNano) + " ms/total, SC for service: " + abbrServiceName + " is: " + gloCounterDiverseSuccess.toString() + " - Response from one of the single-transcation service but and sent back to external caller.");

                if (gloCounterDiverseSuccess % 1000 == 0) {

                    log:printWarn("Success: SCounter " + abbrServiceName + " passed 1000s: " + gloCounterDiverseSuccess.toString());

                }
            }

            if (gloLogLevelNotOffOrError) {

                _ = logNanoTimeStampsLogLevelWARN("VV", abbrServiceName, "Receiving response from caller", serviceCallTimeNano, lastServiceTimeStampNano);

            }
        }
    }
}


function writeFile(json content, string path) returns @tainted error? {

    // Writing the file provided
    io:WritableByteChannel wbc = check io:openWritableFile(path);
    io:WritableCharacterChannel wch = new (wbc, "UTF8");
    var writeJsonResult = wch.writeJson(content);
    closeWc(wch);
    
    return writeJsonResult;

}


function closeWc(io:WritableCharacterChannel wc) {

    // Closing the write channel
    var closeWcResult = wc.close();

    if (closeWcResult is error) {

        log:printError("Error: Closing character write stream failed", closeWcResult);

    }   
}


function readFile(string path) returns @tainted json|error {

    // Reading the file provided
    io:ReadableByteChannel rbc = check io:openReadableFile(path);
    io:ReadableCharacterChannel rch = new (rbc, "UTF8");
    var readJsonResult = rch.readJson();
    closeRc(rch);

    return readJsonResult;
    
}


function closeRc(io:ReadableCharacterChannel rc) {

    // Closing the read channel
    var closeRcResult = rc.close();

    if (closeRcResult is error) {

        log:printError("Error: Closing character read stream failed", closeRcResult);
        
    }
}