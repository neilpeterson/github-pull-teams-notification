# GitHub pull request notification automation

This solution provides an MS Teams notification when scheduled or expected pull requests have not been addressed after a pre-determined time. The notification includes details about the pull request, including diff information. The notification also provides automation for adding a single click pre-determined comment and also free-formed comments.

![](images/card-sample.png)

## Solution components

The logic for this solution is split between two Azure Functions.

- **github-pr-teams-notification** - Time trigger-based Azure Function that uses the GitHub pulls API to identify all pull requests that have a name that matches a filter value and that have been open for a pre-determined time. Once detected, the GitHub pull request diff API is used to get and format the pull request difff. This function then sends the notification to a Teams webhook.
- **github-pr-teams-comment** - Webhook-based Azure Function that is engaged by the notification card. Once engaged, this function adds a comment to the pull request. 

In addition to the Azure Functions, this solution includes Azure Key Vault for storing sensitive application values, Azure Log Analytics workspace for storing solution logs. An Azure Monitor alert is also configured to send a notification email if function execution fails.

> [!NOTE]
> When building this solution, I have encountered a PowerShell multi-line string formatting issue (detailed here - [issue](https://github.com/neilpeterson/github-pull-teams-notification/issues/1)) when running under the Azure Function PowerShell runtime. To work around this issue, the notification function is running from the Azure Function container runtime. This configuration has led to some cost and complexity trade offs. I plan to re-visit and hopefully move the function to the native PowerShell Azure Function runtime..

## Configuration

To configure this solution:

- First, create a Teams webhook on the target Teams channel ([docs](https://docs.microsoft.com/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)).
- Examine and collect the items needed for the solution to function. These are detailed under [soluton deployment parameters](#solution-deployment-parameters). 
- Deploy the templates found in this repository ([instructions](#solution-deployment)).
- Add the Azure functions app webhook from the commenting function to the notification function's app settings ([instructions](#configure-webhook-on-function)).

## Solution deployment parameters

These values are needed when deploying the solution. At deployment time, you are prompted for each.

| Parameter | Type | Description |
|---|---|---|
| GitHubPAT | securestring | GitHub personal access token used for GitHub API authentication ([docs](https://docs.github.com/github/authenticating-to-github/creating-a-personal-access-token)). |
| TeamsWebHook | string | Teams webhook URI. |
| PullRequestsAPI | string | Address of the pulls api for the target GitHub repository ([docs](https://docs.github.com/en/rest/reference/pulls)). |
| PullRequestTitleFilter | string | Only pull requests with this value in the name are processed by the solution. |
| DelayDays | int | Only open pull requests older than this value are processed. |
| EmailAddress | string | Email address where Azure Monitor will send function failure alerts. |
| PreDeterminedComment | string | A pre-determined comment that can be applied to the pull request with a single click. |
| PreDeterminedCommentLabel | string | The value shown on the card for the pre-determined comment button. |
| RemoveSourceControll | bool | When true, removes source control integration. |

## Solution deployment

Create a resource group for the deployment.

```azurecli
az group create --name github-pr-teams --location eastus
```

Run the following command to initiate the deployment. When prompted, enter the value for each parameter.

```azurecli
az deployment group create \
    --resource-group github-pr-teams \
    --template-uri https://raw.githubusercontent.com/neilpeterson/github-pull-teams-notification/remove-comment/deployment/azuredeploy.json
```