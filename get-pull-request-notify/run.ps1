param($Timer)

$Strings = @(
    "Doc GitHub automation"
    "Pull request awaiting review"
    "View PR"
    "Comment on PR"
    "Submit Comment"
)

# Get pull request diff and format for Teams.
function Get-PullRequestDiff ($diff) {

    # Added accept output to header which returns the diff
    $GitHubHeaderDiff = @{authorization = "Token $env:GitHubPAT"; Accept =  "application/vnd.github.v3.diff"}

    # Get Pull Request diff from GitHub diff API.
    Try {$diff = Invoke-RestMethod -Uri $diff.url -Method Get -Headers $GitHubHeaderDiff}
    Catch {throw $_.Exception.Message}

    # Format diff for Teams webhook (add line break)
    $lines = $diff.Split([Environment]::NewLine) | ? { $_ -ne "" }
    foreach ($pull in $lines) {
        $results += "$pull <br>"
    }
    
    return $results
}

# Send a message to a Teams channel which includes the URL of the pull request and pull request details.
function Send-TeamsMessage ($PullDetails, $diff) {

    # Adaptive cards are not yet supported in Teams, here we are using a message card.
    # https://docs.microsoft.com/en-us/outlook/actionable-messages/message-card-reference
    $webhookMessage = @{
        "@type"      = "ActionCard"
        "@context"   = "http://schema.org/extensions"
        "summary"    = $Strings[0]
        "title"      = $Strings[1]
        "themeColor" = '0078D7'
        "sections" = @(
            @{
                "activityTitle" = $PullDetails.user.login
                "activitySubtitle" = $PullDetails.created_at
                "activityImage" = $PullDetails.user.avatar_url
                "activityText" = $PullDetails.title
            }
            @{
                "activityTitle" = "Pull Request Diff"
                "activityText" = $diff
            }
        )
        "potentialAction" = @(
            @{
                '@type' = "OpenUri"
                name = $Strings[2]
                targets = @(
                    @{
                    "os" = "default"
                    "uri" = $PullDetails.html_url
                    }
                )
            }
            @{
                '@type' = "HttpPOST"
                name = $env:PreDeterminedCommentLabel
                target = $env:CommentFunctionWebhook
                body = $env:PreDeterminedComment + ',' + $PullDetails.comments_url
            }
            @{
                '@type' = "ActionCard"
                name = $Strings[3]
                inputs = @(
                    @{
                        "@type" = "TextInput"
                        "id" = "comment"
                        "title" = "Add Comment"
                    }
                )
                actions = @(
                    @{
                        "@type" = "HttpPOST"
                        name = $Strings[4]
                        target = $env:CommentFunctionWebhook
                        body = "{{comment.value}}" + ',' + $PullDetails.comments_url
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 50
         
    $webhookCall = @{
        "URI"         = $env:TeamsWebHook
        "Method"      = 'POST'
        "Body"        = $webhookMessage
        "ContentType" = 'application/json'
    }
    Invoke-RestMethod @webhookCall
}

# Get pull requests from GitHub pulls API.
$GitHubHeader = @{authorization = "Token $env:GitHubPAT"}
Try {$pulls = Invoke-RestMethod -Uri $env:PullRequestsAPI -Method Get -Headers $GitHubHeader}
Catch {throw $_.Exception.Message}

# Process pull requests and send Teams notification if applicable.
foreach ($pull in $pulls) {

    if ($pull.title -like $env:PullRequestTitleFilter) {
        $creationDate = $pull.created_at
        $dateDiff = ((get-date) - ($creationDate))
        
        if ($dateDiff.Days -ge $env:DelayDays) {   
            $finalDiff = Get-PullRequestDiff($pull)
            Send-TeamsMessage $pull $finalDiff
        }
    }
}