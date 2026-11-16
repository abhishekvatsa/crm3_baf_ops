'use strict';
// Only the protected launcher may invoke this operational entry in a new Node.
// This check retires library use; it is not a sandbox for an already hostile VM.
if (require.main !== module || process.execArgv.length !== 1 || process.execArgv[0] !== '--no-global-search-paths' ||
    [
        'NODE_OPTIONS', 'NODE_PATH', 'LD_PRELOAD', 'LD_LIBRARY_PATH', 'DYLD_INSERT_LIBRARIES'
    ].some(k => process.env[k]) ||
    Object.keys(require.cache).some(file => file !== __filename))
    throw Error('BUSINESS_HOSTED_FRESH_ENTRY_REQUIRED');
// The independently protected launcher verifies this distribution and its trust
// file digest before starting an approved Node with no preloads/global search.
// Request data cannot choose the verifier, modules, endpoints or credential scope.
const fs = require('node:fs'), path = require('node:path'), p = require('./business31HostedProtocol.cjs');
const SOURCE_ROOT = path.resolve(__dirname, '../..');
// Fixed failure metadata only. Never serialize an exception or private diagnostic.
const FAILURE_STAGES = Object.freeze(["ENTRY_INPUT","ADMISSION_INITIAL","CLIENT_INITIAL","PLATFORM_INITIAL","OIDC","ADMISSION_RECHECK","STS","BUNDLE_DOWNLOAD","ORIGINAL_REPLAY","ADMISSION_FINAL","CLIENT_RECHECK","PLATFORM_FINAL","CLIENT_FINAL","RESULT_VALIDATION","PRIVATE_CLEANUP","RESULT_STAGING","WORKER_ENTRY","WORKER_INPUT","WORKER_RUNTIME","WORKER_INVENTORY","WORKER_RELOCATION","WORKER_CORE_BINDING","WORKER_CORE_LOAD","WORKER_RELOCATION_CONTEXT","WORKER_GIT","WORKER_BACKEND_CLOSURE","WORKER_RESULT","WORKER_FINAL_INVENTORY","WORKER_FINAL_RUNTIME","WORKER_OUTPUT","CORE_WORKER_PREPARE","CORE_WORKER_PROCESS","CORE_WORKER_RESULT","CORE_WORKER_INPUT_CLEANUP"]);
const FAILURE_REASON_CODES = Object.freeze(["ABSOLUTE_PATH","ADMISSION_CHANGED","ADMITTED_CORE_VERIFIER","ADMITTED_PRODUCERS","ADMITTED_SOURCE","ADMITTED_SOURCE_INTEGRATION","ADMITTED_VERIFIER","ARTIFACT_BOUND","ARTIFACT_DIGEST","ARTIFACT_IDENTITY","ARTIFACT_POPULATION","ARTIFACT_REDIRECT","ARTIFACT_RUN","ARTIFACT_STORAGE_ORIGIN","ARTIFACT_TIME","CALLER_OPTIONS","CANDIDATE","CANDIDATE_ID","CHALLENGE","CHALLENGE_CURRENT","CHALLENGE_DATE","CHALLENGE_DUPLICATE_FILE","CHALLENGE_DURATION","CHALLENGE_FILE","CHALLENGE_FILES","CHALLENGE_IDENTITY","CHALLENGE_INVOCATION","CHALLENGE_PACKAGE_FILES","CHALLENGE_REQUESTER","CHALLENGE_UNEXPECTED_FILES","CLEANUP_OWNERSHIP","CLI","CLIENT_GIT","CLIENT_INPUT_BOUND","CLIENT_INPUT_COMMITMENT","CLIENT_MEASUREMENT_CHANGED","CLIENT_PRODUCER","CLIENT_REPOSITORY","CLIENT_REQUEST_MODE","CLIENT_SELECTED_COMMITMENT","CONFIG_DIGEST","CONSTRUCTION_REQUESTER","CORE_MEMBER","CORE_NODE22","CORE_POPULATION","CORE_ROUTE","CORE_SOURCE","CORE_VERIFIER","DESCRIPTOR_POINTER","EXECUTING_PRODUCER","EXTERNAL_CONFIG_COMMITMENT","FINAL_ADMISSION_CHANGED","FINAL_CLIENT_MEASUREMENT_CHANGED","GITHUB_PATH","GIT_IDENTITY","HTTPS_ENDPOINT","INPUT_BOUNDARY","JOB_IDENTITY","JOB_POPULATION","JOB_STATE","JSON_BOUND","JSON_COMPLEXITY","LIVE_REPOSITORY","LOCAL_INPUT","MAIN_REQUEST","M_REFUSAL_001","M_REFUSAL_002","M_REFUSAL_003","M_REFUSAL_004","M_REFUSAL_005","M_REFUSAL_006","M_REFUSAL_007","M_REFUSAL_008","M_REFUSAL_009","M_REFUSAL_010","M_REFUSAL_011","M_REFUSAL_012","M_REFUSAL_013","M_REFUSAL_014","M_REFUSAL_015","M_REFUSAL_016","M_REFUSAL_017","M_REFUSAL_018","M_REFUSAL_019","M_REFUSAL_020","M_REFUSAL_021","M_REFUSAL_022","M_REFUSAL_023","M_REFUSAL_024","M_REFUSAL_025","M_REFUSAL_026","M_REFUSAL_027","M_REFUSAL_028","M_REFUSAL_029","M_REFUSAL_030","M_REFUSAL_031","M_REFUSAL_032","M_REFUSAL_033","M_REFUSAL_034","M_REFUSAL_035","M_REFUSAL_036","M_REFUSAL_037","M_REFUSAL_038","M_REFUSAL_039","M_REFUSAL_040","M_REFUSAL_041","M_REFUSAL_042","M_REFUSAL_043","M_REFUSAL_044","M_REFUSAL_045","M_REFUSAL_046","M_REFUSAL_047","M_REFUSAL_048","M_REFUSAL_049","M_REFUSAL_050","M_REFUSAL_051","M_REFUSAL_052","M_REFUSAL_053","M_REFUSAL_054","M_REFUSAL_055","M_REFUSAL_056","M_REFUSAL_057","M_REFUSAL_058","M_REFUSAL_059","M_REFUSAL_060","M_REFUSAL_061","M_REFUSAL_062","M_REFUSAL_063","M_REFUSAL_064","M_REFUSAL_065","M_REFUSAL_066","M_REFUSAL_067","M_REFUSAL_068","M_REFUSAL_069","M_REFUSAL_070","M_REFUSAL_071","M_REFUSAL_072","M_REFUSAL_073","M_REFUSAL_074","M_REFUSAL_075","M_REFUSAL_076","M_REFUSAL_077","M_REFUSAL_078","M_REFUSAL_079","M_REFUSAL_080","M_REFUSAL_081","M_REFUSAL_082","M_REFUSAL_083","M_REFUSAL_084","M_REFUSAL_085","M_REFUSAL_086","M_REFUSAL_087","M_REFUSAL_088","M_REFUSAL_089","M_REFUSAL_090","M_REFUSAL_091","M_REFUSAL_092","M_REFUSAL_093","M_REFUSAL_094","M_REFUSAL_095","M_REFUSAL_096","M_REFUSAL_097","M_REFUSAL_098","M_REFUSAL_099","M_REFUSAL_100","M_REFUSAL_101","M_REFUSAL_102","M_REFUSAL_103","M_REFUSAL_104","M_REFUSAL_105","M_REFUSAL_106","M_REFUSAL_107","M_REFUSAL_108","M_REFUSAL_109","M_REFUSAL_110","M_REFUSAL_111","M_REFUSAL_112","M_REFUSAL_113","M_REFUSAL_114","M_REFUSAL_115","M_REFUSAL_116","M_REFUSAL_117","M_REFUSAL_118","M_REFUSAL_119","M_REFUSAL_120","M_REFUSAL_121","M_REFUSAL_122","M_REFUSAL_123","M_REFUSAL_124","M_REFUSAL_125","M_REFUSAL_126","M_REFUSAL_127","M_REFUSAL_128","M_REFUSAL_129","M_REFUSAL_130","M_REFUSAL_131","M_REFUSAL_132","M_REFUSAL_133","M_REFUSAL_134","M_REFUSAL_135","M_REFUSAL_136","M_REFUSAL_137","M_REFUSAL_138","M_REFUSAL_139","M_REFUSAL_140","M_REFUSAL_141","M_REFUSAL_142","M_REFUSAL_143","M_REFUSAL_144","M_REFUSAL_145","M_REFUSAL_146","M_REFUSAL_147","M_REFUSAL_148","M_REFUSAL_149","M_REFUSAL_150","M_REFUSAL_151","M_REFUSAL_152","M_REFUSAL_153","M_REFUSAL_154","M_REFUSAL_155","M_REFUSAL_156","M_REFUSAL_157","M_REFUSAL_158","M_REFUSAL_159","M_REFUSAL_160","M_REFUSAL_161","M_REFUSAL_162","M_REFUSAL_163","M_REFUSAL_164","M_REFUSAL_165","M_REFUSAL_166","M_REFUSAL_167","M_REFUSAL_168","M_REFUSAL_169","M_REFUSAL_170","M_REFUSAL_171","M_REFUSAL_172","M_REFUSAL_173","M_REFUSAL_174","M_REFUSAL_175","M_REFUSAL_176","M_REFUSAL_177","M_REFUSAL_178","M_REFUSAL_179","M_REFUSAL_180","M_REFUSAL_181","M_REFUSAL_182","M_REFUSAL_183","M_REFUSAL_184","M_REFUSAL_185","M_REFUSAL_186","M_REFUSAL_187","M_REFUSAL_188","M_REFUSAL_189","M_REFUSAL_190","M_REFUSAL_191","M_REFUSAL_192","M_REFUSAL_193","M_REFUSAL_194","M_REFUSAL_195","M_REFUSAL_196","M_REFUSAL_197","M_REFUSAL_198","M_REFUSAL_199","M_REFUSAL_200","M_REFUSAL_201","M_REFUSAL_202","M_REFUSAL_203","M_REFUSAL_204","M_REFUSAL_205","M_REFUSAL_206","M_REFUSAL_207","M_REFUSAL_208","M_REFUSAL_209","M_REFUSAL_210","M_REFUSAL_211","M_REFUSAL_212","M_REFUSAL_213","M_REFUSAL_214","M_REFUSAL_215","M_REFUSAL_216","M_REFUSAL_217","M_REFUSAL_218","M_REFUSAL_219","M_REFUSAL_220","M_REFUSAL_221","M_REFUSAL_222","M_REFUSAL_223","M_REFUSAL_224","M_REFUSAL_225","M_REFUSAL_226","M_REFUSAL_227","M_REFUSAL_228","M_REFUSAL_229","M_REFUSAL_230","M_REFUSAL_231","M_REFUSAL_232","M_REFUSAL_233","M_REFUSAL_234","M_REFUSAL_235","NATIVE_FAILURE","NODE_IDENTITY","OIDC_ACTOR","OIDC_ALGORITHM","OIDC_BOUND","OIDC_FORMAT","OIDC_HEADER","OIDC_KEY","OIDC_KEYS","OIDC_REQUEST_ORIGIN","OIDC_RESPONSE","OIDC_SIGNATURE","OIDC_TIME","ORIGINAL_BOUNDED_CLEAN_WORKER_RESULT_REQUIRED","ORIGINAL_BOUNDED_EXISTING_BUNDLE_BYTES_REQUIRED","ORIGINAL_BOUNDED_WORKER_METADATA_REQUIRED","ORIGINAL_CANDIDATE_MOVED_DURING_REPLAY","ORIGINAL_CLOSED_OFFLINE_INPUT_REQUIRED","ORIGINAL_COMPLETE_EXTRACTED_POPULATION_DIFFERS","ORIGINAL_CORE_CLOSURE_SOURCE_CUSTODY_DIFFERS","ORIGINAL_DESCRIPTOR_CHANGED","ORIGINAL_EXACT_PINNED_NODE22_IDENTITY_REQUIRED","ORIGINAL_EXPLICIT_CALLER_CLOCK_REQUIRED","ORIGINAL_FRESH_RECORDED_CORE_WORKER_FAILED","ORIGINAL_OUTER_HELPER_BYTES_DIFFER","ORIGINAL_OUTER_HELPER_NOT_SELECTED","ORIGINAL_OUTER_HELPER_REDIRECTS","ORIGINAL_PINNED_NODE22_REQUIRED","ORIGINAL_PINNED_NODE_CHANGED_BEFORE_WORKER","ORIGINAL_PRIVATE_EVIDENCE_CHANGED_DURING_REPLAY","ORIGINAL_RUNTIME_CHANGED_DURING_REPLAY","ORIGINAL_SELECTED_RUNTIME_DIFFERS","ORIGINAL_SOURCE_MANIFEST_OBJECT_DIFFERS","ORIGINAL_WORKER_COMMITMENTS_DIFFER","ORIGINAL_WORKER_RESULT_PROFILE_AUTHORITY_DIFFERS","PARSE_REFUSAL","PATH_REDIRECT","PR_REQUEST","REGULAR_PATH","REPLAY_CLOSURE","REPLAY_DESCRIPTOR","REPLAY_INCOMPLETE","REPLAY_PRODUCER","REPLAY_SOURCE","REPOSITORY","REQUEST","REQUEST_ID","RESULT_AGE","RESULT_CHALLENGE","RESULT_CHALLENGE_TIME","RESULT_CLIENT_CLOSURE","RESULT_CLIENT_CORE","RESULT_CLOSURE","RESULT_COMMITMENTS","RESULT_CORE_VERIFIER","RESULT_DATE","RESULT_DESCRIPTOR","RESULT_DESTINATION","RESULT_FIELDS","RESULT_JOB_TIME","RESULT_LIMITS","RESULT_M","RESULT_PLATFORM","RESULT_POLICY_CORE","RESULT_PROFILE","RESULT_S","RESULT_TIME","RESULT_TRANSPORT_COMMITMENT","RESULT_V","RUN_ACTOR","RUN_ORIGIN","RUN_STATE","SOURCE","SOURCE_ID","SOURCE_INTEGRATION","SOURCE_INTEGRATION_BINDING","SOURCE_INTEGRATION_PATH","SOURCE_MANIFEST","STALE_MAIN","STALE_OR_FORK_PR","STS_RESULT","TOKEN_UNAVAILABLE","TRANSPORT_ACTUAL_EXPANDED_POPULATION_DIFFERS","TRANSPORT_AUTHENTICATED_EXACT_GENERATION_EVIDENCE_READ_FAILED","TRANSPORT_AUTHORIZED_PRIVATE_EVIDENCE_READ_CREDENTIAL_IS_UNAVAILABLE","TRANSPORT_COMPRESSED_PRIVATE_MEMBER_SIZE_DIGEST_ENCODING_DIFFERS","TRANSPORT_EXPANDED_PRIVATE_MEMBER_SIZE_DIGEST_DIFFERS","TRANSPORT_EXPANDED_PRIVATE_POPULATION_DIFFERS_FROM_IMMUTABLE_DESCRIPTOR","TRANSPORT_EXPANDED_PRIVATE_POPULATION_EXCEEDS_ITS_FIXED_BOUND","TRANSPORT_GIT_REFS_MUST_REMAIN_A_DIRECTORY","TRANSPORT_GOOGLE_GENERATION_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","TRANSPORT_GOOGLE_OBJECT_METADATA_DIFFERS_FROM_IMMUTABLE_GENERATION","TRANSPORT_INVALID_BOUNDED_PRIVATE_MEMBER_ENCODING","TRANSPORT_INVALID_BUNDLE_COMMITMENT","TRANSPORT_INVALID_EXPANDED_PRIVATE_BUNDLE_BOUND","TRANSPORT_INVALID_IMMUTABLE_SOURCE_IDENTITY","TRANSPORT_INVALID_PRIVATE_MEMBER_POPULATION","TRANSPORT_ORIGINAL_PATH_RELOCATION_COMMITMENTS_DIFFER","TRANSPORT_PRIVATE_BUNDLE_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","TRANSPORT_PRIVATE_BUNDLE_SOURCE_DIFFERS","TRANSPORT_PRIVATE_CUSTODY_MUST_NAME_ONE_BOUNDED_EXACT_GENERATION","TRANSPORT_PRIVATE_EXTRACTION_DID_NOT_PRESERVE_EXACT_REGULAR_FILE_BYTES","TRANSPORT_PRIVATE_EXTRACTION_PARENT_MUST_NOT_BE_A_SYMLINK","TRANSPORT_PRIVATE_EXTRACTION_REQUIRES_A_FRESH_ABSOLUTE_DIRECTORY","TRANSPORT_PRIVATE_MEMBER_ESCAPES_EXTRACTION","TRANSPORT_PRIVATE_MEMBER_FILE_DIRECTORY_COLLISION","TRANSPORT_PRIVATE_MEMBER_INVENTORY_CARDINALITY_DIFFERS","TRANSPORT_PRIVATE_MEMBER_INVENTORY_DIFFERS","TRANSPORT_PRIVATE_MEMBER_PATH_PREFIX_CASE_COLLISION","TRANSPORT_PRIVATE_MEMBER_TRAVERSES_SYMLINK","TRANSPORT_PRIVATE_TRANSPORT_DESCRIPTOR_REQUIRED","TRANSPORT_REPEATED_OR_CASE_COLLIDING_PRIVATE_MEMBER","TRANSPORT_SUCCESSOR_TRANSPORT_IS_BUSINESS_ONLY","TRANSPORT_UNSAFE_PORTABLE_MEMBER_PATH","TRANSPORT_UNSUPPORTED_EVIDENCE_HOST_PATH","TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_KIND","TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_NO_ENCODING_FALLBACK_IS_PERMITTED","TRUST_DIGEST","TRUST_FIELDS","TRUST_PROFILE","UNCLASSIFIED","V2_CHALLENGE_REQUIRED","VERIFIER","VERIFIER_MEMBER","VERIFIER_POPULATION","WIF_AUDIENCE","WORKER_ABSOLUTE_PHYSICAL_PATH_REQUIRED","WORKER_BUNDLE_REDIRECTS","WORKER_CLOSED_WORKER_INPUT_REQUIRED","WORKER_COMPLETE_EXTRACTED_INVENTORY_DIFFERS","WORKER_COMPLETE_INVENTORY_CARDINALITY_DIFFERS","WORKER_EXACT_INPUT_BINDING_REQUIRED","WORKER_FINITE_RECORDED_PRODUCER_MAP_REQUIRED","WORKER_FINITE_REGULAR_BUNDLE_POPULATION_REQUIRED","WORKER_FIXED_FRESH_PROCESS_FLAGS_REQUIRED","WORKER_LOADER_ENVIRONMENT_REFUSED","WORKER_MEMBER_CASE_COLLISION","WORKER_MEMBER_CHANGED_DURING_INVENTORY","WORKER_MEMBER_PREFIX_COLLISION","WORKER_ORIGINAL_PATH_REMAINS_AVAILABLE","WORKER_PHYSICAL_PATH_IDENTITY_DIFFERS","WORKER_PHYSICAL_PATH_REDIRECTS","WORKER_PINNED_NODE22_REQUIRED","WORKER_PRIVATE_POPULATION_CHANGED_DURING_CORE_REPLAY","WORKER_RECORDED_CLOSURE_SUBSET_DIFFERS","WORKER_RECORDED_CORE_SOURCE_DIFFERS","WORKER_RECORDED_HELPER_NOT_SELECTED","WORKER_RECORDED_PRODUCER_BINDING_INVALID","WORKER_REGULAR_PHYSICAL_PATH_REQUIRED","WORKER_RELOCATION_COMMITMENT_DIFFERS","WORKER_RUNTIME_CHANGED_DURING_CORE_REPLAY","WORKER_SAFE_MEMBER_REQUIRED","WORKER_SELECTED_RUNTIME_CHANGED","WORKER_SOURCE_MANIFEST_COMMITMENT_DIFFERS","WORKER_UNCHANGED_CORE_REPLAY_INCOMPLETE","WORKER_UNCHANGED_MEMBER_EXPANDED_BYTE_CAP_EXCEEDED","WORKER_UNIQUE_ORIGINAL_ROLE_ROOT_REQUIRED","WORKER_WORKER_INPUT_CHANGED","WORKER_WORKER_METADATA_BOUND_EXCEEDED","WORKER_WORKER_PROFILE_DIFFERS","WORKER_WORKER_RESULT_BOUND_EXCEEDED","WORKFLOW","WORKFLOW_AUTHORITY","WORKFLOW_ID","ZIP_CENTRAL","ZIP_CONTENT","ZIP_DATA_DESCRIPTOR","ZIP_DIRECTORY","ZIP_FLAGS","ZIP_LOCAL","ZIP_LOCAL_CONTENT","ZIP_LOCAL_NAME","ZIP_MEMBER","ZIP_NAME"]);
const NATIVE_CODES = Object.freeze(["EACCES","EAGAIN","EBADF","EBUSY","ECHILD","ECONNREFUSED","ECONNRESET","EEXIST","EFAULT","EFBIG","EINTR","EINVAL","EIO","EISDIR","EMFILE","ENAMETOOLONG","ENFILE","ENOENT","ENOMEM","ENOSPC","ENOTDIR","ENOTEMPTY","ENOTSUP","EPERM","EPIPE","ETIMEDOUT","ERR_BUFFER_TOO_LARGE","ERR_FS_FILE_TOO_LARGE","ERR_INVALID_ARG_TYPE","ERR_OUT_OF_RANGE","ENOBUFS"]), SIGNALS = Object.freeze(["SIGABRT","SIGALRM","SIGBUS","SIGFPE","SIGHUP","SIGILL","SIGINT","SIGKILL","SIGPIPE","SIGQUIT","SIGSEGV","SIGTERM","SIGTRAP"]);
const FAILURE_REASONS = Object.freeze({"BUSINESS_HOSTED_ABSOLUTE_PATH":"ABSOLUTE_PATH","BUSINESS_HOSTED_ADMISSION_CHANGED":"ADMISSION_CHANGED","BUSINESS_HOSTED_ADMITTED_CORE_VERIFIER":"ADMITTED_CORE_VERIFIER","BUSINESS_HOSTED_ADMITTED_PRODUCERS":"ADMITTED_PRODUCERS","BUSINESS_HOSTED_ADMITTED_SOURCE":"ADMITTED_SOURCE","BUSINESS_HOSTED_ADMITTED_SOURCE_INTEGRATION":"ADMITTED_SOURCE_INTEGRATION","BUSINESS_HOSTED_ADMITTED_VERIFIER":"ADMITTED_VERIFIER","BUSINESS_HOSTED_ARTIFACT_BOUND":"ARTIFACT_BOUND","BUSINESS_HOSTED_ARTIFACT_DIGEST":"ARTIFACT_DIGEST","BUSINESS_HOSTED_ARTIFACT_IDENTITY":"ARTIFACT_IDENTITY","BUSINESS_HOSTED_ARTIFACT_POPULATION":"ARTIFACT_POPULATION","BUSINESS_HOSTED_ARTIFACT_REDIRECT":"ARTIFACT_REDIRECT","BUSINESS_HOSTED_ARTIFACT_RUN":"ARTIFACT_RUN","BUSINESS_HOSTED_ARTIFACT_STORAGE_ORIGIN":"ARTIFACT_STORAGE_ORIGIN","BUSINESS_HOSTED_ARTIFACT_TIME":"ARTIFACT_TIME","BUSINESS_HOSTED_CALLER_OPTIONS":"CALLER_OPTIONS","BUSINESS_HOSTED_CANDIDATE":"CANDIDATE","BUSINESS_HOSTED_CANDIDATE_ID":"CANDIDATE_ID","BUSINESS_HOSTED_CHALLENGE":"CHALLENGE","BUSINESS_HOSTED_CHALLENGE_CURRENT":"CHALLENGE_CURRENT","BUSINESS_HOSTED_CHALLENGE_DATE":"CHALLENGE_DATE","BUSINESS_HOSTED_CHALLENGE_DUPLICATE_FILE":"CHALLENGE_DUPLICATE_FILE","BUSINESS_HOSTED_CHALLENGE_DURATION":"CHALLENGE_DURATION","BUSINESS_HOSTED_CHALLENGE_FILE":"CHALLENGE_FILE","BUSINESS_HOSTED_CHALLENGE_FILES":"CHALLENGE_FILES","BUSINESS_HOSTED_CHALLENGE_IDENTITY":"CHALLENGE_IDENTITY","BUSINESS_HOSTED_CHALLENGE_INVOCATION":"CHALLENGE_INVOCATION","BUSINESS_HOSTED_CHALLENGE_PACKAGE_FILES":"CHALLENGE_PACKAGE_FILES","BUSINESS_HOSTED_CHALLENGE_REQUESTER":"CHALLENGE_REQUESTER","BUSINESS_HOSTED_CHALLENGE_UNEXPECTED_FILES":"CHALLENGE_UNEXPECTED_FILES","BUSINESS_HOSTED_CLEANUP_OWNERSHIP":"CLEANUP_OWNERSHIP","BUSINESS_HOSTED_CLI":"CLI","BUSINESS_HOSTED_CLIENT_GIT":"CLIENT_GIT","BUSINESS_HOSTED_CLIENT_INPUT_BOUND":"CLIENT_INPUT_BOUND","BUSINESS_HOSTED_CLIENT_INPUT_COMMITMENT":"CLIENT_INPUT_COMMITMENT","BUSINESS_HOSTED_CLIENT_MEASUREMENT_CHANGED":"CLIENT_MEASUREMENT_CHANGED","BUSINESS_HOSTED_CLIENT_PRODUCER":"CLIENT_PRODUCER","BUSINESS_HOSTED_CLIENT_REPOSITORY":"CLIENT_REPOSITORY","BUSINESS_HOSTED_CLIENT_REQUEST_MODE":"CLIENT_REQUEST_MODE","BUSINESS_HOSTED_CLIENT_SELECTED_COMMITMENT":"CLIENT_SELECTED_COMMITMENT","BUSINESS_HOSTED_CONFIG_DIGEST":"CONFIG_DIGEST","BUSINESS_HOSTED_CONSTRUCTION_REQUESTER":"CONSTRUCTION_REQUESTER","BUSINESS_HOSTED_CORE_MEMBER":"CORE_MEMBER","BUSINESS_HOSTED_CORE_NODE22":"CORE_NODE22","BUSINESS_HOSTED_CORE_POPULATION":"CORE_POPULATION","BUSINESS_HOSTED_CORE_ROUTE":"CORE_ROUTE","BUSINESS_HOSTED_CORE_SOURCE":"CORE_SOURCE","BUSINESS_HOSTED_CORE_VERIFIER":"CORE_VERIFIER","BUSINESS_HOSTED_DESCRIPTOR_POINTER":"DESCRIPTOR_POINTER","BUSINESS_HOSTED_EXECUTING_PRODUCER":"EXECUTING_PRODUCER","BUSINESS_HOSTED_EXTERNAL_CONFIG_COMMITMENT":"EXTERNAL_CONFIG_COMMITMENT","BUSINESS_HOSTED_FINAL_ADMISSION_CHANGED":"FINAL_ADMISSION_CHANGED","BUSINESS_HOSTED_FINAL_CLIENT_MEASUREMENT_CHANGED":"FINAL_CLIENT_MEASUREMENT_CHANGED","BUSINESS_HOSTED_GITHUB_PATH":"GITHUB_PATH","BUSINESS_HOSTED_GIT_IDENTITY":"GIT_IDENTITY","BUSINESS_HOSTED_HTTPS_ENDPOINT":"HTTPS_ENDPOINT","BUSINESS_HOSTED_INPUT_BOUNDARY":"INPUT_BOUNDARY","BUSINESS_HOSTED_JOB_IDENTITY":"JOB_IDENTITY","BUSINESS_HOSTED_JOB_POPULATION":"JOB_POPULATION","BUSINESS_HOSTED_JOB_STATE":"JOB_STATE","BUSINESS_HOSTED_JSON_BOUND":"JSON_BOUND","BUSINESS_HOSTED_JSON_COMPLEXITY":"JSON_COMPLEXITY","BUSINESS_HOSTED_LIVE_REPOSITORY":"LIVE_REPOSITORY","BUSINESS_HOSTED_LOCAL_INPUT":"LOCAL_INPUT","BUSINESS_HOSTED_MAIN_REQUEST":"MAIN_REQUEST","BUSINESS_HOSTED_NODE_IDENTITY":"NODE_IDENTITY","BUSINESS_HOSTED_OIDC_ACTOR":"OIDC_ACTOR","BUSINESS_HOSTED_OIDC_ALGORITHM":"OIDC_ALGORITHM","BUSINESS_HOSTED_OIDC_BOUND":"OIDC_BOUND","BUSINESS_HOSTED_OIDC_FORMAT":"OIDC_FORMAT","BUSINESS_HOSTED_OIDC_HEADER":"OIDC_HEADER","BUSINESS_HOSTED_OIDC_KEY":"OIDC_KEY","BUSINESS_HOSTED_OIDC_KEYS":"OIDC_KEYS","BUSINESS_HOSTED_OIDC_REQUEST_ORIGIN":"OIDC_REQUEST_ORIGIN","BUSINESS_HOSTED_OIDC_RESPONSE":"OIDC_RESPONSE","BUSINESS_HOSTED_OIDC_SIGNATURE":"OIDC_SIGNATURE","BUSINESS_HOSTED_OIDC_TIME":"OIDC_TIME","BUSINESS_HOSTED_PATH_REDIRECT":"PATH_REDIRECT","BUSINESS_HOSTED_PR_REQUEST":"PR_REQUEST","BUSINESS_HOSTED_REGULAR_PATH":"REGULAR_PATH","BUSINESS_HOSTED_REPLAY_CLOSURE":"REPLAY_CLOSURE","BUSINESS_HOSTED_REPLAY_DESCRIPTOR":"REPLAY_DESCRIPTOR","BUSINESS_HOSTED_REPLAY_INCOMPLETE":"REPLAY_INCOMPLETE","BUSINESS_HOSTED_REPLAY_PRODUCER":"REPLAY_PRODUCER","BUSINESS_HOSTED_REPLAY_SOURCE":"REPLAY_SOURCE","BUSINESS_HOSTED_REPOSITORY":"REPOSITORY","BUSINESS_HOSTED_REQUEST":"REQUEST","BUSINESS_HOSTED_REQUEST_ID":"REQUEST_ID","BUSINESS_HOSTED_RESULT_AGE":"RESULT_AGE","BUSINESS_HOSTED_RESULT_CHALLENGE":"RESULT_CHALLENGE","BUSINESS_HOSTED_RESULT_CHALLENGE_TIME":"RESULT_CHALLENGE_TIME","BUSINESS_HOSTED_RESULT_CLIENT_CLOSURE":"RESULT_CLIENT_CLOSURE","BUSINESS_HOSTED_RESULT_CLIENT_CORE":"RESULT_CLIENT_CORE","BUSINESS_HOSTED_RESULT_CLOSURE":"RESULT_CLOSURE","BUSINESS_HOSTED_RESULT_COMMITMENTS":"RESULT_COMMITMENTS","BUSINESS_HOSTED_RESULT_CORE_VERIFIER":"RESULT_CORE_VERIFIER","BUSINESS_HOSTED_RESULT_DATE":"RESULT_DATE","BUSINESS_HOSTED_RESULT_DESCRIPTOR":"RESULT_DESCRIPTOR","BUSINESS_HOSTED_RESULT_DESTINATION":"RESULT_DESTINATION","BUSINESS_HOSTED_RESULT_FIELDS":"RESULT_FIELDS","BUSINESS_HOSTED_RESULT_JOB_TIME":"RESULT_JOB_TIME","BUSINESS_HOSTED_RESULT_LIMITS":"RESULT_LIMITS","BUSINESS_HOSTED_RESULT_M":"RESULT_M","BUSINESS_HOSTED_RESULT_PLATFORM":"RESULT_PLATFORM","BUSINESS_HOSTED_RESULT_POLICY_CORE":"RESULT_POLICY_CORE","BUSINESS_HOSTED_RESULT_PROFILE":"RESULT_PROFILE","BUSINESS_HOSTED_RESULT_S":"RESULT_S","BUSINESS_HOSTED_RESULT_TIME":"RESULT_TIME","BUSINESS_HOSTED_RESULT_TRANSPORT_COMMITMENT":"RESULT_TRANSPORT_COMMITMENT","BUSINESS_HOSTED_RESULT_V":"RESULT_V","BUSINESS_HOSTED_RUN_ACTOR":"RUN_ACTOR","BUSINESS_HOSTED_RUN_ORIGIN":"RUN_ORIGIN","BUSINESS_HOSTED_RUN_STATE":"RUN_STATE","BUSINESS_HOSTED_SOURCE":"SOURCE","BUSINESS_HOSTED_SOURCE_ID":"SOURCE_ID","BUSINESS_HOSTED_SOURCE_INTEGRATION":"SOURCE_INTEGRATION","BUSINESS_HOSTED_SOURCE_INTEGRATION_BINDING":"SOURCE_INTEGRATION_BINDING","BUSINESS_HOSTED_SOURCE_INTEGRATION_PATH":"SOURCE_INTEGRATION_PATH","BUSINESS_HOSTED_SOURCE_MANIFEST":"SOURCE_MANIFEST","BUSINESS_HOSTED_STALE_MAIN":"STALE_MAIN","BUSINESS_HOSTED_STALE_OR_FORK_PR":"STALE_OR_FORK_PR","BUSINESS_HOSTED_STS_RESULT":"STS_RESULT","BUSINESS_HOSTED_TOKEN_UNAVAILABLE":"TOKEN_UNAVAILABLE","BUSINESS_HOSTED_TRUST_DIGEST":"TRUST_DIGEST","BUSINESS_HOSTED_TRUST_FIELDS":"TRUST_FIELDS","BUSINESS_HOSTED_TRUST_PROFILE":"TRUST_PROFILE","BUSINESS_HOSTED_V2_CHALLENGE_REQUIRED":"V2_CHALLENGE_REQUIRED","BUSINESS_HOSTED_VERIFIER":"VERIFIER","BUSINESS_HOSTED_VERIFIER_MEMBER":"VERIFIER_MEMBER","BUSINESS_HOSTED_VERIFIER_POPULATION":"VERIFIER_POPULATION","BUSINESS_HOSTED_WIF_AUDIENCE":"WIF_AUDIENCE","BUSINESS_HOSTED_WORKFLOW":"WORKFLOW","BUSINESS_HOSTED_WORKFLOW_AUTHORITY":"WORKFLOW_AUTHORITY","BUSINESS_HOSTED_WORKFLOW_ID":"WORKFLOW_ID","BUSINESS_HOSTED_ZIP_CENTRAL":"ZIP_CENTRAL","BUSINESS_HOSTED_ZIP_CONTENT":"ZIP_CONTENT","BUSINESS_HOSTED_ZIP_DATA_DESCRIPTOR":"ZIP_DATA_DESCRIPTOR","BUSINESS_HOSTED_ZIP_DIRECTORY":"ZIP_DIRECTORY","BUSINESS_HOSTED_ZIP_FLAGS":"ZIP_FLAGS","BUSINESS_HOSTED_ZIP_LOCAL":"ZIP_LOCAL","BUSINESS_HOSTED_ZIP_LOCAL_CONTENT":"ZIP_LOCAL_CONTENT","BUSINESS_HOSTED_ZIP_LOCAL_NAME":"ZIP_LOCAL_NAME","BUSINESS_HOSTED_ZIP_MEMBER":"ZIP_MEMBER","BUSINESS_HOSTED_ZIP_NAME":"ZIP_NAME","Unsafe portable member path":"TRANSPORT_UNSAFE_PORTABLE_MEMBER_PATH","Unsupported private bundle kind":"TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_KIND","Private transport descriptor required":"TRANSPORT_PRIVATE_TRANSPORT_DESCRIPTOR_REQUIRED","Invalid expanded private bundle bound":"TRANSPORT_INVALID_EXPANDED_PRIVATE_BUNDLE_BOUND","Invalid immutable source identity":"TRANSPORT_INVALID_IMMUTABLE_SOURCE_IDENTITY","Private custody must name one bounded exact generation":"TRANSPORT_PRIVATE_CUSTODY_MUST_NAME_ONE_BOUNDED_EXACT_GENERATION","Invalid bundle commitment":"TRANSPORT_INVALID_BUNDLE_COMMITMENT","Successor transport is business-only":"TRANSPORT_SUCCESSOR_TRANSPORT_IS_BUSINESS_ONLY","Private bundle bytes differ from immutable custody":"TRANSPORT_PRIVATE_BUNDLE_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","Unsupported private bundle; no encoding fallback is permitted":"TRANSPORT_UNSUPPORTED_PRIVATE_BUNDLE_NO_ENCODING_FALLBACK_IS_PERMITTED","Private bundle source differs":"TRANSPORT_PRIVATE_BUNDLE_SOURCE_DIFFERS","Invalid private member population":"TRANSPORT_INVALID_PRIVATE_MEMBER_POPULATION","Repeated or case-colliding private member":"TRANSPORT_REPEATED_OR_CASE_COLLIDING_PRIVATE_MEMBER","Private member path prefix case collision":"TRANSPORT_PRIVATE_MEMBER_PATH_PREFIX_CASE_COLLISION","Invalid bounded private member encoding":"TRANSPORT_INVALID_BOUNDED_PRIVATE_MEMBER_ENCODING","Compressed private member size/digest/encoding differs":"TRANSPORT_COMPRESSED_PRIVATE_MEMBER_SIZE_DIGEST_ENCODING_DIFFERS","Expanded private population exceeds its fixed bound":"TRANSPORT_EXPANDED_PRIVATE_POPULATION_EXCEEDS_ITS_FIXED_BOUND","Private member inventory cardinality differs":"TRANSPORT_PRIVATE_MEMBER_INVENTORY_CARDINALITY_DIFFERS","Expanded private population differs from immutable descriptor":"TRANSPORT_EXPANDED_PRIVATE_POPULATION_DIFFERS_FROM_IMMUTABLE_DESCRIPTOR","Private member file/directory collision":"TRANSPORT_PRIVATE_MEMBER_FILE_DIRECTORY_COLLISION","Private member inventory differs":"TRANSPORT_PRIVATE_MEMBER_INVENTORY_DIFFERS","Original path relocation commitments differ":"TRANSPORT_ORIGINAL_PATH_RELOCATION_COMMITMENTS_DIFFER","Expanded private member size/digest differs":"TRANSPORT_EXPANDED_PRIVATE_MEMBER_SIZE_DIGEST_DIFFERS","Actual expanded population differs":"TRANSPORT_ACTUAL_EXPANDED_POPULATION_DIFFERS","Private extraction requires a fresh absolute directory":"TRANSPORT_PRIVATE_EXTRACTION_REQUIRES_A_FRESH_ABSOLUTE_DIRECTORY","Private extraction parent must not be a symlink":"TRANSPORT_PRIVATE_EXTRACTION_PARENT_MUST_NOT_BE_A_SYMLINK","Private member escapes extraction":"TRANSPORT_PRIVATE_MEMBER_ESCAPES_EXTRACTION","Private member traverses symlink":"TRANSPORT_PRIVATE_MEMBER_TRAVERSES_SYMLINK","Private extraction did not preserve exact regular-file bytes":"TRANSPORT_PRIVATE_EXTRACTION_DID_NOT_PRESERVE_EXACT_REGULAR_FILE_BYTES","Git refs must remain a directory":"TRANSPORT_GIT_REFS_MUST_REMAIN_A_DIRECTORY","Authorized private-evidence read credential is unavailable":"TRANSPORT_AUTHORIZED_PRIVATE_EVIDENCE_READ_CREDENTIAL_IS_UNAVAILABLE","Unsupported evidence host/path":"TRANSPORT_UNSUPPORTED_EVIDENCE_HOST_PATH","Google object metadata differs from immutable generation":"TRANSPORT_GOOGLE_OBJECT_METADATA_DIFFERS_FROM_IMMUTABLE_GENERATION","Google generation bytes differ from immutable custody":"TRANSPORT_GOOGLE_GENERATION_BYTES_DIFFER_FROM_IMMUTABLE_CUSTODY","Authenticated exact-generation evidence read failed":"TRANSPORT_AUTHENTICATED_EXACT_GENERATION_EVIDENCE_READ_FAILED","Business original-path replay v2: outer helper not selected":"ORIGINAL_OUTER_HELPER_NOT_SELECTED","Business original-path replay v2: outer helper redirects":"ORIGINAL_OUTER_HELPER_REDIRECTS","Business original-path replay v2: outer helper bytes differ":"ORIGINAL_OUTER_HELPER_BYTES_DIFFER","Business original-path replay v2: pinned Node22 required":"ORIGINAL_PINNED_NODE22_REQUIRED","Business original-path replay v2: bounded worker metadata required":"ORIGINAL_BOUNDED_WORKER_METADATA_REQUIRED","Business original-path replay v2: pinned Node changed before worker":"ORIGINAL_PINNED_NODE_CHANGED_BEFORE_WORKER","Business original-path replay v2: fresh recorded core worker failed":"ORIGINAL_FRESH_RECORDED_CORE_WORKER_FAILED","Business original-path replay v2: bounded clean worker result required":"ORIGINAL_BOUNDED_CLEAN_WORKER_RESULT_REQUIRED","Business original-path replay v2: worker result profile/authority differs":"ORIGINAL_WORKER_RESULT_PROFILE_AUTHORITY_DIFFERS","Business original-path replay v2: closed offline input required":"ORIGINAL_CLOSED_OFFLINE_INPUT_REQUIRED","Business original-path replay v2: exact pinned Node22 identity required":"ORIGINAL_EXACT_PINNED_NODE22_IDENTITY_REQUIRED","Business original-path replay v2: explicit caller clock required":"ORIGINAL_EXPLICIT_CALLER_CLOCK_REQUIRED","Business original-path replay v2: bounded existing bundle bytes required":"ORIGINAL_BOUNDED_EXISTING_BUNDLE_BYTES_REQUIRED","Business original-path replay v2: descriptor changed":"ORIGINAL_DESCRIPTOR_CHANGED","Business original-path replay v2: source manifest object differs":"ORIGINAL_SOURCE_MANIFEST_OBJECT_DIFFERS","Business original-path replay v2: complete extracted population differs":"ORIGINAL_COMPLETE_EXTRACTED_POPULATION_DIFFERS","Business original-path replay v2: selected runtime differs":"ORIGINAL_SELECTED_RUNTIME_DIFFERS","Business original-path replay v2: worker commitments differ":"ORIGINAL_WORKER_COMMITMENTS_DIFFER","Business original-path replay v2: core closure source/custody differs":"ORIGINAL_CORE_CLOSURE_SOURCE_CUSTODY_DIFFERS","Business original-path replay v2: private evidence changed during replay":"ORIGINAL_PRIVATE_EVIDENCE_CHANGED_DURING_REPLAY","Business original-path replay v2: runtime changed during replay":"ORIGINAL_RUNTIME_CHANGED_DURING_REPLAY","Business original-path replay v2: candidate moved during replay":"ORIGINAL_CANDIDATE_MOVED_DURING_REPLAY"});
let failureStage = 'ENTRY_INPUT', primaryFailure = null, cleanupFailed = false;
function ownData(value, key) {
    if (value === null || (typeof value !== 'object' && typeof value !== 'function')) return undefined;
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (descriptor && !Object.hasOwn(descriptor, 'value')) throw Error('BUSINESS_DIAGNOSTIC_ACCESSOR');
    return descriptor ? descriptor.value : undefined;
}
function rememberFailure(error) {
    if (primaryFailure !== null) return;
    try {
        const nested = ownData(error, 'business31Diagnostic');
        const fields = ['schemaVersion','stage','reason','nativeCode','workerExit','workerSignal','workerCleanupFailed','cleanupFailed'];
        if (nested && Object.getPrototypeOf(nested) === Object.prototype &&
            Object.getOwnPropertySymbols(nested).length === 0 &&
            Object.getOwnPropertyNames(nested).sort().join(',') === [...fields].sort().join(',')) {
            const value = Object.fromEntries(fields.map(key => [key, ownData(nested, key)]));
            if (value.schemaVersion === 1 && FAILURE_STAGES.includes(value.stage) && FAILURE_REASON_CODES.includes(value.reason) &&
                (value.nativeCode === null || NATIVE_CODES.includes(value.nativeCode)) &&
                (value.workerExit === null || (Number.isInteger(value.workerExit) && value.workerExit >= 0 && value.workerExit <= 4294967295)) &&
                (value.workerSignal === null || SIGNALS.includes(value.workerSignal)) &&
                typeof value.workerCleanupFailed === 'boolean' && value.cleanupFailed === false) {
                primaryFailure = {...value}; delete primaryFailure.schemaVersion; return;
            }
        }
        const code = ownData(error, 'code'), message = ownData(error, 'message');
        const nativeCode = NATIVE_CODES.includes(code) ? code : null;
        primaryFailure = {stage: failureStage, reason: typeof message === 'string' && Object.hasOwn(FAILURE_REASONS, message)
            ? FAILURE_REASONS[message] : nativeCode ? 'NATIVE_FAILURE' :
                (error !== null && typeof error === 'object' && Object.getPrototypeOf(error) === SyntaxError.prototype) ? 'PARSE_REFUSAL' : 'UNCLASSIFIED',
            nativeCode, workerExit: null, workerSignal: null, workerCleanupFailed: false};
    } catch {
        primaryFailure = {stage: FAILURE_STAGES.includes(failureStage) ? failureStage : 'ENTRY_INPUT', reason: 'UNCLASSIFIED',
            nativeCode: null, workerExit: null, workerSignal: null, workerCleanupFailed: false};
    }
}
function reportFailure(error) {
    const fallback = 'Business hosted replay failed; no result is admissible. {"schemaVersion":1,"stage":"ENTRY_INPUT","reason":"UNCLASSIFIED","nativeCode":null,"workerExit":null,"workerSignal":null,"workerCleanupFailed":false,"cleanupFailed":false}\n';
    let line = fallback;
    try {
        rememberFailure(error);
        const record = {schemaVersion: 1, ...primaryFailure, cleanupFailed};
        const candidate = 'Business hosted replay failed; no result is admissible. ' + JSON.stringify(record) + '\n';
        if (Buffer.byteLength(candidate) <= 512 && FAILURE_STAGES.includes(record.stage)) line = candidate;
    } catch { /* A formatter failure never exposes a secondary exception. */ }
    try { fs.writeSync(2, line); } catch { /* A closed pipe remains a failure. */ }
    process.exitCode = 1;
}
function measureClient31(options) {
    const {trust, request, repositoryRoot, gitExecutable, clientInputFile, clientInputSha256} = options;
    p.need(request.schemaVersion === 2 && /^[A-F0-9]{64}$/.test(clientInputSha256), 'CLIENT_INPUT_COMMITMENT');
    p.verifyClientHelpers31(trust);
    const file = p.regular(clientInputFile);
    p.need(fs.statSync(file).size > 0 && fs.statSync(file).size <= 128 * 1024, 'CLIENT_INPUT_BOUND');
    const raw = fs.readFileSync(file);
    p.need(p.sha(raw) === clientInputSha256, 'CLIENT_INPUT_COMMITMENT');
    const input = p.json(raw, 128 * 1024);
    p.same(input.repositoryRoot, repositoryRoot, 'CLIENT_REPOSITORY');
    p.same(input.gitExecutable, gitExecutable, 'CLIENT_GIT');
    const canonical = require('./business31SourceAdmission.cjs').canonical;
    p.need(p.sha(Buffer.from(canonical(input.selected))) === request.challenge.clientSelectionSha256,
        'CLIENT_SELECTED_COMMITMENT');
    return require('./business31HostedClient.cjs').measureBusinessHostedClient31({trust, request, input});
}
function admit31({ trust, request, repositoryRoot, gitExecutable, sourceManifest }) {
    p.validateTrust31(trust);
    p.validateRequest31(request);
    const v2 = p.isV2Trust31(trust);
    p.need(!v2 || request.schemaVersion === 2, 'V2_CHALLENGE_REQUIRED');
    p.verifyExecuting31(trust, SOURCE_ROOT);
    p.verifyReplayHelpers31(trust);
    p.need(p.sha(fs.readFileSync(p.regular(gitExecutable))) === trust.gitSha256, 'GIT_IDENTITY');
    const source = require('./business31SourceAdmission.cjs');
    p.need(p.sha(source.canonical(sourceManifest)) === trust.sourceManifestSha256, 'SOURCE_MANIFEST');
    const candidate = {commit: request.candidate.commit, tree: request.candidate.tree,
        ref: 'refs/heads/business31-admitted-' + request.candidate.commit};
    const envelope = v2 ? require('./business31TrustedInputV2.cjs').createTrustedEnvelopeV2(trust, candidate) : {
        schemaVersion: 1, profile: 'build31-business-trusted-input-v1', verifier: trust.verifier,
        source: {
            commit: trust.source.commit, tree: trust.source.tree
        }, candidate
    };
    const api = v2 ? require('./business31PrivateDescriptorV2.cjs') : require('./business31PrivateDescriptor.cjs');
    const verify = v2 ? api.verifyBusiness31DescriptorPreparationV2 : api.verifyBusiness31DescriptorPreparation;
    const proof = verify({
        repositoryRoot, gitExecutable, gitSha256: trust.gitSha256, envelope,
        descriptorPointer: request.descriptorPointer, expectedSourceManifestSha256: trust.sourceManifestSha256
    });
    const repo = require('./business31TrustedInput.cjs').openTrustedGitRepository31({
        repositoryRoot, gitExecutable, gitSha256: trust.gitSha256
    });
    const validate = v2 ? api.validateBusiness31PrivateDescriptorV2 : api.validateBusiness31PrivateDescriptor;
    const descriptor = validate(api.json(repo.readBlob(request.descriptorPointer.commit, request.descriptorPointer.file)));
    p.same(descriptor.source, trust.source, 'ADMITTED_SOURCE');
    p.same(descriptor.verifier, {
        commit: trust.verifier.commit, tree: trust.verifier.tree
    }, 'ADMITTED_VERIFIER');
    p.same(descriptor.producerBindings, trust.verifier.files, 'ADMITTED_PRODUCERS');
    if (v2) {
        p.same(descriptor.coreVerifier, trust.coreVerifier, 'ADMITTED_CORE_VERIFIER');
        p.same(descriptor.sourceIntegration, trust.sourceIntegration, 'ADMITTED_SOURCE_INTEGRATION');
    }
    p.need(proof.inputBoundaryVerified === true, 'INPUT_BOUNDARY');
    return {
        envelope, descriptor
    };
}
async function githubOidc31(trust, request) {
    const u = new URL(process.env.ACTIONS_ID_TOKEN_REQUEST_URL || 'https://invalid.invalid/');
    p.need(u.protocol === 'https:' && !u.username && !u.password && !u.port && /^[a-z0-9-]+\.actions\.githubusercontent\.com$/.test(u.hostname), 'OIDC_REQUEST_ORIGIN');
    u.searchParams.set('audience', trust.wifAudience);
    const body = p.json((await p.request31(u.href, {
        headers: {
            Authorization: 'Bearer ' + p.token(process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN)
        }, maxBytes: 32768
    })).bytes, 32768);
    p.exact(body, ['value'], 'OIDC_RESPONSE');
    const jwks = p.json((await p.request31(p.ISSUER + '/.well-known/jwks', {
        maxBytes: 128 * 1024
    })).bytes, 128 * 1024);
    p.verifyOidc31(body.value, jwks, trust, request);
    return body.value;
}
async function exchangeReadOnly31(trust, subjectToken) {
    const body = Buffer.from(new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange', audience: trust.wifAudience,
        requested_token_type: 'urn:ietf:params:oauth:token-type:access_token', subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
        scope: 'https://www.googleapis.com/auth/devstorage.read_only', subject_token: subjectToken
    }).toString());
    const v = p.json((await p.request31('https://sts.googleapis.com/v1/token', {
        method: 'POST', headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
        }, body, maxBytes: 32768
    })).bytes, 32768);
    p.need(v.token_type === 'Bearer' && v.issued_token_type === 'urn:ietf:params:oauth:token-type:access_token' && Number.isInteger(v.expires_in) && v.expires_in > 0 && v.expires_in <= 3600, 'STS_RESULT');
    return p.token(v.access_token);
}
async function replayHosted31(options) {
    p.exact(options, [
        'trust', 'request', 'repositoryRoot', 'gitExecutable', 'sourceManifest', 'privateParent',
        ...(options.request?.schemaVersion === 2 ? ['clientInputFile', 'clientInputSha256'] : [])
    ], 'CALLER_OPTIONS');
    options = p.json(Buffer.from(JSON.stringify(options)));
    const { trust, request, repositoryRoot, gitExecutable, sourceManifest, privateParent } = options;
    const startedAtUtc = new Date().toISOString();
    failureStage = 'ADMISSION_INITIAL';
    const first = admit31(options);
    failureStage = 'CLIENT_INITIAL';
    const client = request.schemaVersion === 2 ? measureClient31(options) : null;
    if (client) p.need(Date.parse(request.challenge.requestedAtUtc) <= Date.now() &&
        Date.now() < Date.parse(request.challenge.expiresAtUtc), 'CHALLENGE_CURRENT');
    // All imports above are fixed V code. Private credentials are requested only
    // after complete Git/source/descriptor admission and fresh platform checks.
    failureStage = 'PLATFORM_INITIAL';
    await p.observe31(trust, request, process.env.GITHUB_TOKEN, false);
    failureStage = 'OIDC';
    let oidc = await githubOidc31(trust, request), accessToken = null, bundle = null, owned = null;
    try {
        failureStage = 'ADMISSION_RECHECK';
        const second = admit31(options);
        p.same(second, first, 'ADMISSION_CHANGED');
        failureStage = 'STS';
        accessToken = await exchangeReadOnly31(trust, oidc);
        oidc = null;
        const v2 = p.isV2Trust31(trust);
        const transport = v2 ? require('./privateEvidenceBundle31V2.cjs') : require('./privateEvidenceBundle31.cjs');
        failureStage = 'BUNDLE_DOWNLOAD';
        bundle = await (v2 ? transport.downloadExactGenerationV2 : transport.downloadExactGeneration31)(first.descriptor, accessToken, 'business');
        accessToken = null;
        const parent = p.regular(privateParent, true);
        owned = fs.mkdtempSync(path.join(parent, 'business31-hosted-'));
        fs.chmodSync(owned, 0o700);
        const replayApi = v2 ? require('./business31OriginalPathReplayV2.cjs') : require('./business31OriginalPathReplay.cjs');
        const verify = v2 ? replayApi.verifyBusiness31OriginalPathReplayV2 : replayApi.verifyBusiness31OriginalPathReplay;
        failureStage = 'ORIGINAL_REPLAY';
        const replay = verify({
            repositoryRoot, gitExecutable, gitSha256: trust.gitSha256,
            envelope: first.envelope, descriptorPointer: request.descriptorPointer, sourceManifest, expectedSourceManifestSha256: trust.sourceManifestSha256,
            bundleBytes: bundle, extractionRoot: path.join(owned, 'evidence'), nowUtc: new Date().toISOString(),
            ...(v2 ? {nodeSha256: trust.nodeSha256} : {})
        });
        p.need(replay.recordedSemanticsReplayed === true && replay.originalPathsUnavailable === true, 'REPLAY_INCOMPLETE');
        p.same(replay.source, trust.source, 'REPLAY_SOURCE');
        p.need(replay.descriptorSha256 === request.descriptorPointer.sha256, 'REPLAY_DESCRIPTOR');
        p.same(replay.closure.closurePointer, first.descriptor.closurePointer, 'REPLAY_CLOSURE');
        failureStage = 'ADMISSION_FINAL';
        p.same(admit31(options), first, 'FINAL_ADMISSION_CHANGED');
        failureStage = 'CLIENT_RECHECK';
        if (client) p.same(measureClient31(options), client, 'CLIENT_MEASUREMENT_CHANGED');
        failureStage = 'PLATFORM_FINAL';
        await p.observe31(trust, request, process.env.GITHUB_TOKEN, false);
        failureStage = 'CLIENT_FINAL';
        if (client) p.same(measureClient31(options), client, 'FINAL_CLIENT_MEASUREMENT_CHANGED');
        const result = {
            schemaVersion: request.schemaVersion, documentType: 'build31-business-hosted-result', profile: trust.profile,
            verifier: {
                commit: trust.verifier.commit, tree: trust.verifier.tree
            }, ...(v2 ? {coreVerifier: p.coreVerifierSummary31(trust)} : {}),
            source: trust.source, candidate: request.candidate, descriptorPointer: request.descriptorPointer,
            closurePointer: first.descriptor.closurePointer, commitments: {
                bundleSha256: first.descriptor.custody.sha256, membersSha256: replay.membersSha256,
                relocationSha256: replay.relocationSha256, sourceManifestSha256: trust.sourceManifestSha256,
                ...p.transportCommitments31(trust)
            },
            platform: {
                repositoryId: trust.repository.id, workflowId: trust.workflow.id, workflowCommit: trust.verifier.commit, runId: request.runId, runAttempt: request.runAttempt, environment: trust.workflow.environment
            },
            startedAtUtc, completedAtUtc: new Date().toISOString(), recordedSemanticsReplayed: true,
            limits: {
                ownerIdentityAuthenticated: false, originalProcessExecutionAuthenticated: false, deploymentAuthorized: false, constructionAuthorized: false, distributionAuthorized: false
            }, ...(client ? {challenge: request.challenge, client} : {})
        };
        failureStage = 'RESULT_VALIDATION';
        return p.validateResult31(result, trust, request);
    }
    catch (error) { rememberFailure(error); throw error; }
    finally {
        failureStage = 'PRIVATE_CLEANUP';
        try {
        oidc = null;
        accessToken = null;
        if (bundle)
            bundle.fill(0);
        // Only the exclusive mkdtemp directory created above is removed. Abrupt
        // process/host death requires destruction of the protected ephemeral job.
        if (owned) {
            p.need(path.dirname(owned) === path.resolve(privateParent) && path.basename(owned).startsWith('business31-hosted-'), 'CLEANUP_OWNERSHIP');
            p.regular(owned, true);
            fs.rmSync(owned, {
                recursive: true, force: false
            });
        }
        } catch (error) { cleanupFailed = true; throw error; }
    }
}
async function main() {
    const clientMode = process.argv.length === 14;
    p.need((process.argv.length === 10 || clientMode) && process.argv[2] === '--trust' && process.argv[4] === '--trust-sha256' && process.argv[6] === '--request' && process.argv[8] === '--output' &&
        (!clientMode || (process.argv[10] === '--client-input' && process.argv[12] === '--client-input-sha256')), 'CLI');
    const trust = p.readTrustedConfiguration31(process.argv[3], process.argv[5]);
    const input = p.json(fs.readFileSync(p.regular(process.argv[7])));
    p.exact(input, [
        'request', 'repositoryRoot', 'gitExecutable', 'sourceManifest', 'privateParent'
    ], 'LOCAL_INPUT');
    p.need(clientMode === (input.request?.schemaVersion === 2), 'CLIENT_REQUEST_MODE');
    const output = path.resolve(process.argv[9]);
    p.need(path.basename(output) === p.RESULT_NAME && !fs.existsSync(output), 'RESULT_DESTINATION');
    p.regular(path.dirname(output), true);
    const result = await replayHosted31({
        trust, ...input, ...(clientMode ? {clientInputFile: process.argv[11], clientInputSha256: process.argv[13]} : {})
    });
    failureStage = 'RESULT_STAGING';
    fs.writeFileSync(output, JSON.stringify(result) + '\n', {
        flag: 'wx', mode: 0o600
    });
}
if (require.main === module)
    main().catch(reportFailure);
