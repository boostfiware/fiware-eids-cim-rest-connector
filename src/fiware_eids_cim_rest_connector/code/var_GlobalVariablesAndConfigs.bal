import ballerina/auth;
import ballerina/http;
import ballerina/cache;
import ballerina/config;
import ballerina/crypto;


// Reading environment variables
string gloConnectorID = config:getAsString("envConnectorID");
string gloX509SKIAKI = config:getAsString("envX509SKIAKI");
string gloProviderRestApiBaseServiceClusterUri = config:getAsString("envProviderRestApiBaseServiceClusterUri");

string gloDatDapsName = config:getAsString("envDatDapsName");
string gloDatEndpointUrl = config:getAsString("envDatEndpointUrl");
string gloDatEndpointPath = config:getAsString("envDatEndpointPath");
string gloDatIssuer = config:getAsString("envDatIssuer");
// string gloDatAudience = config:getAsString("envDatAudience");

string gloDapsKeyStoreInBallerinaRelativeFileInfo = config:getAsString("envDapsKeyStoreInBallerinaRelativeFileInfo");
string gloDapsKeystorePrivateKeyAlias = config:getAsString("envDapsKeystorePrivateKeyAlias");
string gloDapsKeyStorePassword = config:getAsString("envDapsKeyStorePassword");

string gloDapsTrustStoreInBallerinaRelativeFileInfo = config:getAsString("envDapsTrustStoreInBallerinaRelativeFileInfo");
string gloDapsTrustStoreAlias = config:getAsString("envDapsTrustStoreAlias");
string gloDapsTrustStorePassword = config:getAsString("envDapsTrustStorePassword");

string gloDomainKeyFileInBallerinaRelativeFileInfo = config:getAsString("envDomainKeyFileInBallerinaRelativeFileInfo");
string gloDomainCertFileInBallerinaRelativeFileInfo = config:getAsString("envDomainCertFileInBallerinaRelativeFileInfo");

int gloIncTokenCacheCapacity = config:getAsInt("envIncTokenCacheCapacity");
int gloIncTokenCacheMaxAgeSec = config:getAsInt("envIncTokenCacheMaxAgeSec");
int gloIncTokenCacheCleanUpSec = config:getAsInt("envIncTokenCacheCleanUpSec");

string gloDatTokenInternValidAddOnSecondsString = config:getAsString("envDatTokenInternValidAddOnSecondsString");

string gloIDSInfoModelVersionOutgoing = config:getAsString("envIDSInfoModelVersionOutgoing");

string gloInfraFwdSplitHeaderRoot1 = config:getAsString("envInfraFwdSplitHeaderRoot");
string gloInfraFwdSplitHeaderRoot2 = config:getAsString("envInfraFwdSplitHeaderRoot")+"/*";

string gloInfraFwdMultiPartRoot1 = config:getAsString("envInfraFwdMultiPartRoot");
string gloInfraFwdMultiPartRoot2 = config:getAsString("envInfraFwdMultiPartRoot")+"/*";

string gloInfraFwdHeaderOnlyRoot1 = config:getAsString("envInfraFwdHeaderOnlyRoot");
string gloInfraFwdHeaderOnlyRoot2 = config:getAsString("envInfraFwdHeaderOnlyRoot")+"/*";

string gloFilePathSelfDesriptionInBallerina = config:getAsString("envFilePathSelfDesriptionInBallerina");

string gloIngressHostNameFQN = config:getAsString("envIngressHostNameFQN");
string gloIngressHostNameFQNPort = config:getAsString("envIngressHostNameFQNPort");

int gloDatTokenInternValidAddOnSeconds = config:getAsInt("envDatTokenInternValidAddOnSecondsString");

boolean gloKeyRockActivationExtInt = config:getAsBoolean("envKeyRockActivationExtInt");
boolean gloKeyRockActivationIntExt = config:getAsBoolean("envKeyRockActivationIntExt");
boolean gloKeyRockActivationIntInt = config:getAsBoolean("envKeyRockActivationIntInt");
string gloKeyRockSH256Secret = config:getAsString("envKeyRockSH256Secret");
string gloKeyRockAppID = config:getAsString("envKeyRockAppID");
string gloKeyRockAppAzfDomain = config:getAsString("envKeyRockAppAzfDomain");
string gloXacmlEndpointUrl = config:getAsString("envXacmlEndpointUrl") + gloKeyRockAppAzfDomain;

string gloBasePath = config:getAsString("envBasePath");

string gloLogLevel = config:getAsString("b7a.log.level");
boolean gloLogLevelNotOffOrError = gloLogLevel == "DEBUG" || gloLogLevel == "INFO" || gloLogLevel == "TRACE" || gloLogLevel == "WARN" || gloLogLevel == "ALL";

int gloGeneralTimeOutInMillis = config:getAsInt("envTimeOutInMillis");
int gloPoolMaxActiveConnections = config:getAsInt("envPoolMaxActiveConnections");
int gloPoolMaxIdleConnections = config:getAsInt("envPoolMaxIdleConnections");
int gloPoolWaitTimeInMillis = config:getAsInt("envPoolWaitTimeInMillis");
int gloRetryCount = config:getAsInt("envRetryCount");
int gloRetryIntervalInMillis = config:getAsInt("envRetryIntervalInMillis");



// Ballerina internal global variables
string gloDatTokenJWT = "";
string gloDatTokenJWTID = "";
int gloDatTokenInternValidEndTime = 0;



// Global variables for path calculations
int gloInfraFwdXXRootLength = gloBasePath.length() + gloInfraFwdMultiPartRoot1.length();
int gloDataRootLength = gloBasePath.length() + 5;



// Success/Failure counter: Checking 1000s of Succussful calls in WARN mode, one for each main input channel
int gloCounterDataInExtIntSHHOSuccess = 0;
int gloCounterDataInExtIntSHHOFailure = 0;
int gloCounterDataInIntIntSuccess = 0;
int gloCounterDataInIntIntFailure = 0;
int gloCounterDataInIntExtSHSuccess = 0;
int gloCounterDataInIntExtSHFailure = 0;
int gloCounterDiverseSuccess = 0;
int gloCounterDiverseFailure = 0;



// Global TrustStore for Ballerina HTTPS calls to clients
crypto:TrustStore gloTrustStoreBallerina = {
    path: gloDapsTrustStoreInBallerinaRelativeFileInfo,
    password: gloDapsTrustStorePassword
};

// Global Listener configuration with local userAuthenticatation
http:ListenerConfiguration gloListenerConfigAuth = {
    http1Settings: {
        keepAlive: http:KEEPALIVE_AUTO,
        maxPipelinedRequests: 10,
        maxUriLength: 4096,
        maxHeaderSize: 8192,
        maxEntityBodySize: -1
    },
    secureSocket: {
        keyFile: gloDomainKeyFileInBallerinaRelativeFileInfo,
        certFile: gloDomainCertFileInBallerinaRelativeFileInfo,
        certValidation: {
            enable: false,
            cacheSize: 0,
            cacheValidityPeriod: 0
        }
    },
    timeoutInMillis: 10000,
    auth: {
        authHandlers: [gloBasicAuthHandler]
    },
    server: "FIWARE EIDS CIM REST CONNECTOR"
};

// Basic Auth Provider for Global Listener configuration with local userAuthenticatation
auth:InboundBasicAuthProvider gloBasicAuthProvider = new;
http:BasicAuthHandler gloBasicAuthHandler = new (gloBasicAuthProvider);

// Global Listener configuration without local userAuthenticatation
http:ListenerConfiguration gloListenerConfigNoAuth = {
    http1Settings: {
        keepAlive: http:KEEPALIVE_AUTO,
        maxPipelinedRequests: 10,
        maxUriLength: 4096,
        maxHeaderSize: 8192,
        maxEntityBodySize: -1
    },
    //secureSocket: {
    //    keyFile: gloDomainKeyFileInBallerinaRelativeFileInfo,
    //    certFile: gloDomainCertFileInBallerinaRelativeFileInfo,
    //    certValidation: {
    //        enable: false,
    //        cacheSize: 0,
    //        cacheValidityPeriod: 0
    //    }
    //},
    timeoutInMillis: 10000,
    server: "FIWARE EIDS CIM REST CONNECTOR"
};

// Global Client configuration for infrastructure components - currently there are unsafe Certificates out there
http:ClientConfiguration gloStandardInfraStructureClientConfig = {
    http1Settings:{
        keepAlive: http:KEEPALIVE_AUTO,
        chunking: http:CHUNKING_NEVER
    },
    timeoutInMillis: 10000,
    followRedirects:{
        enabled: false
    },
    poolConfig:{
        maxActiveConnections: 20,
        maxIdleConnections: 5,
        waitTimeInMillis: 10000
    },
    retryConfig:{
        count: 3,
        intervalInMillis: 1000
    },
    secureSocket: {
        trustStore: gloTrustStoreBallerina,
        disable: true
    }
};

// Global Client configuration for external services - NO CHUNKING FOR TESTS WITH ENG CONNECTOR!!!
http:ClientConfiguration gloExternalClientConfig = {
    http1Settings:{
        keepAlive: http:KEEPALIVE_AUTO,
        chunking: http:CHUNKING_NEVER
    },
    timeoutInMillis: 10000,
    followRedirects:{
        enabled: true,
        maxCount: 3
    },
    poolConfig:{
        maxActiveConnections: 20,
        maxIdleConnections: 5,
        waitTimeInMillis: 10000
    },
    retryConfig:{
        count: 3,
        intervalInMillis: 1000
    },
    secureSocket: {
        trustStore: gloTrustStoreBallerina,
        disable: true
    }
};

// Global Client configuration for internal central provider REST API within the Kubernetes cluster, HTTP! services, no secureSocket
http:ClientConfiguration gloInternalClientConfig = {
    http1Settings:{
        keepAlive: http:KEEPALIVE_AUTO,
        chunking: http:CHUNKING_AUTO
    },
    timeoutInMillis: 10000,
    followRedirects:{
        enabled: false
    },
    poolConfig:{
        maxActiveConnections: 20,
        maxIdleConnections: 5,
        waitTimeInMillis: 10000
    },
    retryConfig:{
        count: 3,
        intervalInMillis: 1000
    }
};
// Endpoint for accessing the internal central provider REST API within the Kubernetes cluster
http:Client gloProviderRestApiEndpoint = new (gloProviderRestApiBaseServiceClusterUri, gloInternalClientConfig);




// Cache configuration
cache:Cache gloConnectorCache = new({
    capacity: gloIncTokenCacheCapacity,
    evictionFactor: 0.2,
    defaultMaxAgeInSeconds: gloIncTokenCacheMaxAgeSec,
    cleanupIntervalInSeconds: gloIncTokenCacheCleanUpSec
});





// Lists of MessageTypes
string[] gloSHDataRequestMessageTypes = [
    "ids:RequestMessage"
];
string[] gloSHDataResponseMessageTypes = [
    "ids:ResponseMessage"
];
string[] gloHODataRequestMessageTypes = [
    "ids:RequestMessage"
];
string[] gloMPFwdRequestMessageTypes = [
    // only with Brokers
    "ids:ConnectorUpdateMessage", 
    "ids:ConnectorUnavailableMessage", 
    "ids:QueryMessage",

    // with Brokers and other Connectors
    "ids:DescriptionRequestMessage"
];
string[] gloDataInSHHOExtDataRequestMessageTypes = [
    "ids:RequestMessage",
    "ids:QueryMessage"
];
// The following 3 groups may NOT overlap
string[] gloMPFwdRequestMessageTypesWithSelfDescriptionPayload = [
    // only with Brokers
    "ids:ConnectorUpdateMessage"
];
string[] gloMPFwdRequestMessageTypesWithPlainTextQueryMessagePayload = [
    // only with Brokers
    "ids:QueryMessage"
];
string[] gloMPFwdRequestMessageTypesWithoutAnyPayload = [
    // only with Brokers
    "ids:ConnectorUnavailableMessage",
    "ids:DescriptionRequestMessage"
];