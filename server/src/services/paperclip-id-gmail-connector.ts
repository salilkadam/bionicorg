/**
 * @deprecated Bionic ID is identity-only. Import the Bionic Cloud
 * connector names from `bionic-cloud-connector.ts` for new code.
 *
 * These aliases keep source compatibility while deployments and persisted app
 * definitions move from the former Bionic ID broker prototype.
 */
export {
  GMAIL_CONNECTOR_SCOPES,
  GMAIL_MCP_URL,
  GOOGLE_WORKSPACE_CONNECTOR_PROFILES,
  PaperclipCloudConnectorError as PaperclipIdConnectorError,
  createPaperclipCloudConnector as createPaperclipIdGmailConnector,
  bionicCloudConnectorCapabilitiesFromEnv as bionicIdGoogleConnectorCapabilitiesFromEnv,
  bionicCloudConnectorConfigFromEnv as bionicIdGmailConnectorConfigFromEnv,
} from "./bionic-cloud-connector.js";

export type {
  PaperclipCloudConnector as PaperclipIdGmailConnector,
  PaperclipCloudConnector as PaperclipIdGoogleWorkspaceConnector,
  PaperclipCloudConnectorConfig as PaperclipIdGmailConnectorConfig,
  PaperclipCloudConnectorEnvironment as PaperclipIdConnectorEnvironment,
  PaperclipCloudConnectorOperation as PaperclipIdConnectorOperation,
  SealedGmailCredentials,
  SealedGoogleWorkspaceCredentials,
} from "./bionic-cloud-connector.js";
