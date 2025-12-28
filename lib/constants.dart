const bool isDev = bool.fromEnvironment('IS_DEV');

const kClientId = "app.kiddos.fhir.clarity";
// const kLaunch = 'eyJoIjoiMSJ9';
// const kLaunch = 'eyJoIjoiMSIsImIiOiI4MjEiLCJlIjoiMyJ9';
// const kLaunch = 'eyJoIjoiMSIsImIiOiI4MjEiLCJqIjoiMSIsImUiOiIzIn0';
// const kLaunch = 'eyJoIjoiMSIsImIiOiI4MjEiLCJpIjoiMSIsImoiOiIxIiwiZSI6IjMifQ';
// const kLaunch = 'eyJoIjoiMSIsImIiOiIxMzkwIiwiaiI6IjEiLCJlIjoiMyJ9';
                                    
const kCallbackScheme = 'clarity.kiddos.app';
// const kScopes = 'openid user/*.* patient/*.read launch/patient';
// const kScopes = 'patient/*.read launch';
const kScopes = 'openid fhirUser offline_access user/*.* patient/*.* launch/encounter launch/patient profile';
const kRedirectUri = '$kCallbackScheme://callback';
// const kTokenUrl = '$kFhirBaseUrl/auth/token';
// const kAud = '$kFhirBaseUrl/fhir';
// const kAud = '$kFhirBaseUrl/sim/$kLaunch/fhir';
// const kRequestUrl = kAud;
