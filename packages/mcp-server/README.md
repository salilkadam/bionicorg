# Bionic MCP Server

Model Context Protocol server for Bionic.

This package is a thin MCP wrapper over the existing Bionic REST API. It does
not talk to the database directly and it does not reimplement business logic.

## Authentication

The server reads its configuration from environment variables:

- `BIONIC_API_URL` - Bionic base URL, for example `http://localhost:3100`
- `BIONIC_API_KEY` - bearer token used for `/api` requests
- `BIONIC_COMPANY_ID` - optional default company for company-scoped tools
- `BIONIC_AGENT_ID` - optional default agent for checkout helpers
- `BIONIC_RUN_ID` - optional run id forwarded on mutating requests

Inside an active heartbeat, Bionic also injects `BIONIC_RUNTIME_TOOLS_*` variables. They enable the run-scoped `connections_search` and `connection_request` tools and expire with the run.

## Usage

```sh
npx -y @bionicai/mcp-server
```

Or locally in this repo:

```sh
pnpm --filter @bionicai/mcp-server build
node packages/mcp-server/dist/stdio.js
```

## Tool Surface

Run-scoped connection tools:

- `connections_search`
- `connection_request`

Read tools:

- `bionicMe`
- `bionicInboxLite`
- `bionicListAgents`
- `bionicGetAgent`
- `bionicListIssues`
- `bionicGetIssue`
- `bionicGetHeartbeatContext`
- `bionicListComments`
- `bionicGetComment`
- `bionicListIssueApprovals`
- `bionicListDocuments`
- `bionicGetDocument`
- `bionicListDocumentRevisions`
- `bionicListProjects`
- `bionicGetProject`
- `bionicGetIssueWorkspaceRuntime`
- `bionicWaitForIssueWorkspaceService`
- `bionicListGoals`
- `bionicGetGoal`
- `bionicListApprovals`
- `bionicGetApproval`
- `bionicGetApprovalIssues`
- `bionicListApprovalComments`

Write tools:

- `bionicCreateIssue`
- `bionicUpdateIssue`
- `bionicCheckoutIssue`
- `bionicReleaseIssue`
- `bionicAddComment`
- `bionicSuggestTasks`
- `bionicAskUserQuestions`
- `bionicRequestConfirmation`
- `bionicUpsertIssueDocument`
- `bionicRestoreIssueDocumentRevision`
- `bionicControlIssueWorkspaceServices`
- `bionicCreateApproval`
- `bionicLinkIssueApproval`
- `bionicUnlinkIssueApproval`
- `bionicApprovalDecision`
- `bionicAddApprovalComment`

Escape hatch:

- `bionicApiRequest`

`bionicApiRequest` is limited to paths under `/api` and JSON bodies. It is
meant for endpoints that do not yet have a dedicated MCP tool.
