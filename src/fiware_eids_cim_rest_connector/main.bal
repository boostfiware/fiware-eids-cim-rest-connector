// !!! there is an error here with displaying the environmental variables in VS Code
// for ballarina build * comment the following line... for working with only 1 error, uncomment it
// import ballerina/filepath;

import ballerina/http;
import ballerina/mime;
import ballerina/time;
import ballerina/istio;
import ballerina/kubernetes;


@istio:Gateway {
    name: "$env{INGRESS_GW_NAME}",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    servers: [
        {
            port: {
                number: 443,
                name: "https",
                protocol: "HTTPS"
            },
            hosts: [
                "$env{INGRESS_GW_HOST_NAME_FQN}"
            ],
            tls: {
                httpsRedirect: false,
                mode: "PASSTHROUGH"
            }
        }
    ]
}
// No istio-service here because it currently does not support tls passthrough 
// First k8s-Service and Ballerina listener on port 9090: Main incoming external services with IDS-Handshake and authorization
@kubernetes:Service {
    name: "$env{SERVICE_NAME_EXTERNAL_INTERNAL}-srv",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    portName: "https-$env{SERVICE_NAME_EXTERNAL_INTERNAL}-srv",
    serviceType: "ClusterIP",
    sessionAffinity: "ClientIP"
}
listener http:Listener FIWARE_IDSA_CIM_REST_OpenSource_Connector_External_EP = new(9090, gloListenerConfigAuth);


// Global k8s settings for all services, internal and external
@kubernetes:PersistentVolumeClaim {
    volumeClaims: [
        {
            name: "$env{PVC_NAME_IN_K8S}",
            mountPath: "$env{PVC_MOUNT_PATH_IN_BALLERINA}",
            readOnly: false,
            accessMode: "ReadWriteOnce",
            volumeClaimSize: "$env{PVC_SIZE_IN_K8S}"
        }
    ]
}

@kubernetes:Secret {
    secrets: [
        {
            name: "$env{SECRET_NAME_BALLERINA_KEYS_AND_CERTS_IN_K8S}",
            mountPath: "$env{SECRET_MOUNT_PATH_IN_BALLERINA}",
            data: ["$env{DAPS_KEYSTORE_LOCAL_ABSOLUTE_FILE_INFO}",
                "$env{DAPS_TRUSTSTORE_LOCAL_ABSOLUTE_FILE_INFO}",
                "$env{DOMAIN_KEYFILE_LOCAL_ABSOLUTE_FILE_INFO}",
                "$env{DOMAIN_CERTFILE_LOCAL_ABSOLUTE_FILE_INFO}"]
        }
    ]
}

@kubernetes:ConfigMap {
    conf: "./src/fiware_eids_cim_rest_connector/resources/ballerina.conf",
        configMaps:[
        {
            mountPath: "$env{INFO_HTML_FILES_MOUNT_PATH_IN_BALLERINA}",
            data: ["./src/fiware_eids_cim_rest_connector/resources/connectorinfo.html",
                "./src/fiware_eids_cim_rest_connector/resources/404info.html"]
        }
    ]
}

@kubernetes:Deployment {
    registry: "$env{DOCKER_REGISTRY}",
    username: "$env{DOCKER_USERNAME}",
    password: "$env{DOCKER_PASSWORD}",
    image: "$env{DOCKER_IMAGENAME}",
    baseImage: "$env{DOCKER_BASE_IMAGE}",
    cmd: "CMD java $env{DOCKER_CMD_INSERT} -jar ${APP}${CONFIG_FILE}",
    buildImage: false,
    push: false, // false
    //dockerHost: "tcp://192.168.99.101:2376",
    //dockerCertPath:"/Users/gernotboge/.minikube/certs",//
    namespace: "$env{NAMESPACE}",
    name: "$env{DEPLOYMENT_NAME}",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    env: {
        "envConnectorID": "$env{CONNECTOR_ID}",
        "envX509SKIAKI": "$env{X509_SKI_AKI}",
        "envProviderRestApiBaseServiceClusterUri": "$env{PROVIDER_REST_API_BASE_SERVICE_CLUSTER_URI}",

        "envDatDapsName": "$env{DAT_DAPS_NAME}",
        "envDatEndpointUrl": "$env{DAT_ENDPOINT_URL}",
        "envDatEndpointPath": "$env{DAT_ENDPOINT_PATH}",
        "envDatIssuer": "$env{DAT_ISSUER}",
        // "envDatAudience": "$env{DAT_AUDIENCE}",

        "envDapsKeyStoreInBallerinaRelativeFileInfo": "$env{DAPS_KEYSTORE_IN_BALLERINA_RELATIVE_FILE_INFO}",
        "envDapsKeystorePrivateKeyAlias": "$env{DAPS_KEYSTORE_PRIVATE_KEY_ALIAS}",
        "envDapsKeyStorePassword": "$env{DAPS_KEYSTORE_PASSWORD}",

        "envDapsTrustStoreInBallerinaRelativeFileInfo": "$env{DAPS_TRUSTSTORE_IN_BALLERINA_RELATIVE_FILE_INFO}",
        "envDapsTrustStoreAlias": "$env{DAPS_TRUSTSTORE_ALIAS}",
        "envDapsTrustStorePassword": "$env{DAPS_TRUSTSTORE_PASSWORD}",

        "envDomainKeyFileInBallerinaRelativeFileInfo": "$env{DOMAIN_KEYFILE_IN_BALLERINA_RELATIVE_FILE_INFO}",
        "envDomainCertFileInBallerinaRelativeFileInfo": "$env{DOMAIN_CERTFILE_IN_BALLERINA_RELATIVE_FILE_INFO}",

        "envIncTokenCacheCapacity": "$env{INC_TOKEN_CACHE_CAPACITY}",
        "envIncTokenCacheMaxAgeSec": "$env{INC_TOKEN_CACHE_MAXAGE_SEC}",
        "envIncTokenCacheCleanUpSec": "$env{INC_TOKEN_CACHE_CLEANUP_SEC}",

        "envDatTokenInternValidAddOnSecondsString": "$env{DAT_TOKEN_INTERN_VALID_ADDON_SECONDS}",

        "envIDSInfoModelVersionOutgoing": "$env{IDS_INFOMODEL_VERSION_OUTGOING}",

        "envInfraFwdSplitHeaderRoot": "$env{INFRA_FWD_SPLITHEADER_ROOT}",
        "envInfraFwdMultiPartRoot": "$env{INFRA_FWD_MULTIPART_ROOT}",
        "envInfraFwdHeaderOnlyRoot": "$env{INFRA_FWD_HEADERONLY_ROOT}",

        "envFilePathSelfDesriptionInBallerina": "$env{SELFDESCRIPTION_PATH_AND_FILE_INFO_IN_PVC_IN_K8S}",

        "envIngressHostNameFQN": "$env{INGRESS_GW_HOST_NAME_FQN}",
        "envIngressHostNameFQNPort": "$env{INGRESS_GW_HOST_NAME_FQN_PORT}",

        "envKeyRockActivationExtInt": "$env{KEYROCK_ACTIVATION_EXT_INT}",
        "envKeyRockActivationIntExt": "$env{KEYROCK_ACTIVATION_INT_EXT}",
        "envKeyRockActivationIntInt": "$env{KEYROCK_ACTIVATION_INT_INT}",

        "envKeyRockSH256Secret": "$env{KEYROCK_SH256_SECRET}",
        "envKeyRockAppID": "$env{KEYROCK_APP_ID}",
        "envKeyRockAppAzfDomain": "$env{KEYROCK_APP_AZF_DOMAIN}",
        "envXacmlEndpointUrl": "$env{XACML_ENDPOINT_URL}",
        
        "envBasePath": "$env{BASE_PATH}",

        "envTimeOutInMillis": "$env{TIME_OUT_IN_MILLIS}",
        "envPoolMaxActiveConnections": "$env{POOL_MAX_ACTIVE_CONNECTIONS}",
        "envPoolMaxIdleConnections": "$env{POOL_MAX_IDLE_CONNECTIONS}",
        "envPoolWaitTimeInMillis": "$env{POOL_WAIT_TIMT_IN_MILLIS}",
        "envRetryCount": "$env{RETRY_COUNT}",
        "envRetryIntervalInMillis": "$env{RETRY_INTERVAL_IN_MILLIS}"

    },
    singleYAML: false,
    imagePullPolicy: "Always",
    // No numeric values for livenessProbe with environment variables so far
    livenessProbe: {
        port: 9090,
        initialDelaySeconds: 10,
        periodSeconds: 5
    },
    // No numeric values for readinessProbe with environment variables so far
    readinessProbe: {
        port: 9090,
        initialDelaySeconds: 10,
        periodSeconds: 5
    },
    updateStrategy:{
        strategyType: kubernetes:STRATEGY_ROLLING_UPDATE,
        maxSurge: 1,
        maxUnavailable: 0
    },
    replicas: 1
}

// First Ballerina service: Main incoming external services with IDS-Handshake and authorization
@http:ServiceConfig {
    basePath: gloBasePath
}
service serviceMainExternalInternal on FIWARE_IDSA_CIM_REST_OpenSource_Connector_External_EP {

    // GET SelfDescripion on / (root)
    // no auth provider
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/",
        produces: ["application/ld+json"],
        auth: {
            enabled: false
        }
    }
    resource function getSelfDescriptionRoot(http:Caller caller, http:Request req) {
        getSelfDescription(caller, req);
    }

    // GET (POST) SelfDescription from Multipart on /infrastructure
    // no auth provider
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/infrastructure",
        consumes: ["multipart/mixed","multipart/form-data"],
        produces: ["application/ld+json"],
        auth: {
            enabled: false
        }
    }
    resource function postMultipartSDMessagesInfrastructure(http:Caller caller, http:Request req) {
        getSelfDescriptionWithMPRequest(caller, req);
    }

    // GET SelfDescripion on /infrastructure/selfdescription
    // no auth provider
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/infrastructure/selfdescription",
        produces: ["application/ld+json"],
        auth: {
            enabled: false
        }
    }
    resource function getSelfDescription(http:Caller caller, http:Request req) {
        getSelfDescription(caller, req);
    }

    // POST SelfDescripion on /infrastructure/selfdescription
    // auth scope1
    @http:ResourceConfig {
        methods: ["POST"],
        path: "/infrastructure/selfdescription",
        consumes: ["application/ld+json"],
        produces: ["application/json"],
        auth: {
        	scopes: ["scope1"]
        }
    }
    resource function postSelfDescription(http:Caller caller, http:Request req) {
        postSelfDescription(caller, req);
    }

    // PUT SelfDescripion on /infrastructure/selfdescription
    // auth scope1
    @http:ResourceConfig {
        methods: ["PUT"],
        path: "/infrastructure/selfdescription",
        consumes: ["application/ld+json"],
        produces: ["application/json"],
        auth: {
        	scopes: ["scope1"]
        }
    }
    resource function putSelfDescription(http:Caller caller, http:Request req) {
        putSelfDescription(caller, req);
    }

    // DELETE SelfDescripion on /infrastructure/selfdescription
    // auth scope1
    @http:ResourceConfig {
        methods: ["DELETE"],
        path: "/infrastructure/selfdescription",
        produces: ["application/json"],
        auth: {
        	scopes: ["scope1"]
        }
    }
    resource function deleteSelfDescription(http:Caller caller, http:Request req) {
        deleteSelfDescription(caller, req);
    }

    // GET ConnectorInfo on /connectorinfo
    // no auth provider
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/connectorinfo",
        produces: ["text/html"],
        auth: {
            enabled: false
        }
    }
    resource function getConnectorInfo(http:Caller caller, http:Request req) {
        getConnectorInfo(caller, req);
    }

    // GET 404Info on /404
    // no auth provider
    @http:ResourceConfig {
        methods: ["GET"],
        path: "/404",
        produces: ["text/html"],
        auth: {
            enabled: false
        }
    }
    resource function getInfo404(http:Caller caller, http:Request req) {
        getInfo404(caller, req);
    }

    // POST Forward Multipart Messages on /infrastructure/fwd-mp-root
    // auth scope1, scope2
    @http:ResourceConfig {
        methods: ["POST"],
        path: gloInfraFwdMultiPartRoot1,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardMPMessage1(http:Caller caller, http:Request req) {
        forwardMPMessage(caller, req);
    }

    // auth scope1, scope2
    @http:ResourceConfig {
        methods: ["POST"],
        path: gloInfraFwdMultiPartRoot2,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardMPMessage2(http:Caller caller, http:Request req) {
        forwardMPMessage(caller, req);
    }


    // POST Forward Splitheader Messages on /infrastructure/fwd-sh-root
    // auth scope1, scope2
    @http:ResourceConfig {
        path: gloInfraFwdSplitHeaderRoot1,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardSHMessage1(http:Caller caller, http:Request req) {
        forwardSHMessage(caller, req);
    }

    // auth scope1, scope2
    @http:ResourceConfig {
        path: gloInfraFwdSplitHeaderRoot2,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardSHMessage2(http:Caller caller, http:Request req) {
        forwardSHMessage(caller, req);
    }


    // POST Forward HeaderHeader Messages on /infrastructure/fwd-ho-root
    // auth scope1, scope2
    @http:ResourceConfig {
        path: gloInfraFwdHeaderOnlyRoot1,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardHOMessage1(http:Caller caller, http:Request req) {
        forwardHOMessage(caller, req);
    }

    // auth scope1, scope2
    @http:ResourceConfig {
        path: gloInfraFwdHeaderOnlyRoot2,
        auth: {
        	scopes: ["scope1", "scope2"]
        }
    }
    resource function forwardHOMessage2(http:Caller caller, http:Request req) {
        forwardHOMessage(caller, req);
    }

    // All verbs SplitHeader or HeaderOnly Messages on /data
    // no auth provider
    @http:ResourceConfig {
        path: "/data",
        auth: {
            enabled: false
        }
    }
    resource function dataInServiceSHHOExternal1(http:Caller caller, http:Request req) {

        int serviceCallTime = time:nanoTime();

        var bodyParts = req.getBodyParts();

        if (bodyParts is mime:Entity[]) {

            getSelfDescriptionWithMPRequest(caller, req);

        } else {

            dataInExtIntSHHO(caller, req, serviceCallTime);

        }
    }

    // no auth provider
    @http:ResourceConfig {
        path: "/data/*",
        auth: {
            enabled: false
        }
    }
    resource function dataInServiceSHHOExternal2(http:Caller caller, http:Request req) {
        int serviceCallTime = time:nanoTime();
        dataInExtIntSHHO(caller, req, serviceCallTime);

    }
}


@istio:VirtualService {
    name: "$env{SERVICE_NAME_INTERNAL_EXTERNAL}-vs",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    hosts: [
        "$env{VSERVICE_NAME_INTERNAL_EXTERNAL_HOST_NAME_FQN}"
    ]
}
// Second k8s-Service and Ballerina Listener 9091: Internal services outgoing to external
@kubernetes:Service {
    name: "$env{SERVICE_NAME_INTERNAL_EXTERNAL}-srv",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    portName: "https-$env{SERVICE_NAME_INTERNAL_EXTERNAL}-srv",
    serviceType: "NodePort", // Change to ClusterIP
    nodePort: 31391 // delete
}
listener http:Listener FIWARE_IDSA_CIM_REST_OpenSource_Connector_Internal_External_EP = new(9091, gloListenerConfigNoAuth);

// Second Ballerina Services: Internal services outgoing to external
@http:ServiceConfig {
    basePath: "/" //gloBasePath
}
service serviceInternalExternal on FIWARE_IDSA_CIM_REST_OpenSource_Connector_Internal_External_EP {

    // no auth provider
    @http:ResourceConfig {
        path: "/"
    }
    resource function dataServiceInternalExternal1(http:Caller caller, http:Request req) {
        int serviceCallTime = time:nanoTime();
        dataInInternalExternal(caller, req, serviceCallTime);
    }

    // no auth provider
    @http:ResourceConfig {
        path: "/*"
    }
    resource function dataServiceInternalExternal2(http:Caller caller, http:Request req) {
        int serviceCallTime = time:nanoTime();
        dataInInternalExternal(caller, req, serviceCallTime);
    }
}



@istio:VirtualService {
    name: "$env{SERVICE_NAME_INTERNAL_INTERNAL}-vs",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    hosts: [
        "$env{VSERVICE_NAME_INTERNAL_INTERNAL_HOST_NAME_FQN}"
    ]
}
// Third k8s-Service and Ballerina Listener 9092: Internal services to internal CB
@kubernetes:Service {
    name: "$env{SERVICE_NAME_INTERNAL_INTERNAL}-srv",
    labels: {
        "connector/stage": "$env{LABEL_STAGE}",
        "connector/project": "$env{LABEL_PROJECT}",
        "connector/connectorID": "$env{LABEL_CONNECTOR_ID}"
    },
    portName: "https-$env{SERVICE_NAME_INTERNAL_INTERNAL}-srv",
    serviceType: "NodePort", // Change to ClusterIP
    nodePort: 31392 // delete
}
listener http:Listener FIWARE_IDSA_CIM_REST_OpenSource_Connector_Internal_Internal_EP = new(9092, gloListenerConfigNoAuth);

// Third Ballerina Services: Internal services to internal CB
@http:ServiceConfig {
    basePath: "/" //gloBasePath
}
service serviceInternalInternal on FIWARE_IDSA_CIM_REST_OpenSource_Connector_Internal_Internal_EP {

    // no auth provider
    @http:ResourceConfig {
        path: "/"
    }
    resource function dataServiceInternalInternal1(http:Caller caller, http:Request req) {
        int serviceCallTime = time:nanoTime();
        dataInInternalInternal(caller, req, serviceCallTime);
    }

    // no auth provider
    @http:ResourceConfig {
        path: "/*"
    }
    resource function dataServiceInternalInternal2(http:Caller caller, http:Request req) {
        int serviceCallTime = time:nanoTime();
        dataInInternalInternal(caller, req, serviceCallTime);
    }
}
