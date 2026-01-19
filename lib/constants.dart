const bool isDev = bool.fromEnvironment('IS_DEV');

const kClientId = "app.kiddos.fhir.clarity";
const kCallbackScheme = 'clarity.kiddos.app';
const kScopes = 'openid fhirUser offline_access user/*.* patient/*.* launch/encounter launch/patient profile';
const kRedirectUri = '$kCallbackScheme://callback';
// const kTokenUrl = '$kFhirBaseUrl/auth/token';
// const kAud = '$kFhirBaseUrl/fhir';
// const kAud = '$kFhirBaseUrl/sim/$kLaunch/fhir';
// const kRequestUrl = kAud;
