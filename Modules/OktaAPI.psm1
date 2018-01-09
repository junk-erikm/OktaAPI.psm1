$headers = @{}
$baseUrl = ""
$userAgent = "OktaAPIWindowsPowerShell/0.1"

# Call this before calling Okta API functions.
function Connect-Okta($token, $baseUrl) {
    $script:headers = @{"Authorization" = "SSWS $token"; "Accept" = "application/json"; "Content-Type" = "application/json"}
    $script:baseUrl = "$baseUrl/api/v1"
}

# App functions - http://developer.okta.com/docs/api/resources/apps.html

function Get-OktaAppUser($appid, $userid) {
    Invoke-Method GET "/apps/$appid/users/$userid"
}

function Get-OktaAppUsers($appid, $limit = 20, $url = "/apps/$appid/users?limit=$limit") {
    Invoke-PagedMethod $url
}

function Set-OktaAppUser($appid, $userid, $appuser) {
    Invoke-Method POST "/apps/$appid/users/$userid" $appuser
}

# Event functions - http://developer.okta.com/docs/api/resources/events.html

function Get-OktaEvents($startDate, $filter, $limit = 1000, $url = "/events?startDate=$startDate&filter=$filter&limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}

# Factor (MFA) functions - http://developer.okta.com/docs/api/resources/factors.html

function Get-OktaFactor($userid, $factorid) {
    Invoke-Method GET "/users/$userid/factors/$factorid"
}

function Get-OktaFactors($userid) {
    Invoke-Method GET "/users/$userid/factors"
}

function Set-OktaFactor($userid, $factor) {
    Invoke-Method POST "/users/$userid/factors" $factor
}

# Group functions - http://developer.okta.com/docs/api/resources/groups.html

# $group = New-OktaGroup @{profile = @{name = "a group"; description = "its description"}}
function New-OktaGroup($group) {
    Invoke-Method POST "/groups" $group
}

function Get-OktaGroup($id) {
    Invoke-Method GET "/groups/$id"
}

# $groups = Get-OktaGroups "PowerShell" 'type eq "OKTA_GROUP"'
function Get-OktaGroups($q, $filter, $limit = 200, $url = "/groups?q=$q&filter=$filter&limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}

function Get-OktaGroupMember($id, $limit = 200, $url = "/groups/$id/users?limit=$limit", $paged = $false) {
    if ($paged) {
        Invoke-PagedMethod $url
    } else {
        Invoke-Method GET $url
    }
}

function Add-OktaGroupMember($groupid, $userid) {
    $noContent = Invoke-Method PUT "/groups/$groupid/users/$userid"
}

function Remove-OktaGroupMember($groupid, $userid) {
    $noContent = Invoke-Method DELETE "/groups/$groupid/users/$userid"
}

# Logs functions - https://developer.okta.com/docs/api/resources/system_log

function Get-OktaLogs($since, $until, $filter, $q, $sortOrder = "ASCENDING", $limit = 100, $url = "/logs?since=$since&until=$until&filter=$filter&q=$q&sortOrder=$sortOrder&limit=$limit") {
    Invoke-PagedMethod $url
}

# User functions - http://developer.okta.com/docs/api/resources/users.html

# $user = New-OktaUser @{profile = @{login = $login; email = $email; firstName = $firstName; lastName = $lastName}}
function New-OktaUser($user, $activate = $true) {
    Invoke-Method POST "/users?activate=$activate" $user
}

function Get-OktaUser($id) {
    Invoke-Method GET "/users/$id"
}

function Get-OktaUsers($q, $filter, $limit = 200, $url = "/users?q=$q&filter=$filter&limit=$limit") {
    Invoke-PagedMethod $url
}

function Set-OktaUser($id, $user) {
# Only the profile properties specified in the request will be modified when using the POST method.
    Invoke-Method POST "/users/$id" $user
}

function Get-OktaUserGroups($id) {
    Invoke-Method GET "/users/$id/groups"
}

function Enable-OktaUser($id, $sendEmail = $true) {
    Invoke-Method POST "/users/$id/lifecycle/activate?sendEmail=$sendEmail"
}

function Disable-OktaUser($id) {
    $noContent = Invoke-Method POST "/users/$id/lifecycle/deactivate"
}

function Set-OktaUserResetPassword($id, $sendEmail = $true) {
    Invoke-Method POST "/users/$id/lifecycle/reset_password?sendEmail=$sendEmail"
}

function Set-OktaUserExpirePassword($id) {
    Invoke-Method POST "/users/$id/lifecycle/expire_password"
}

function Remove-OktaUser($id) {
    Invoke-Method DELETE "/users/$id"
}

# Core functions

function Invoke-Method($method, $path, $body) {
    $url = $baseUrl + $path
    $jsonBody = ConvertTo-Json -compress $body
    Invoke-RestMethod $url -Method $method -Headers $headers -Body $jsonBody -UserAgent $userAgent
}

function Invoke-PagedMethod($url) {
    if ($url -notMatch '^http') {$url = $baseUrl + $url}
    $response = Invoke-WebRequest $url -Method GET -Headers $headers -UserAgent $userAgent
    $links = @{}
    if ($response.Headers.Link) { # Some searches (eg List Users with Search) do not support pagination.
        foreach ($header in $response.Headers.Link.split(",")) {
            if ($header -match '<(.*)>; rel="(.*)"') {
                $links[$matches[2]] = $matches[1]
            }
        }
    }
    @{objects = ConvertFrom-Json $response.content
      nextUrl = $links.next
      response = $response
      limitLimit = [int64]$response.Headers.'X-Rate-Limit-Limit';
      limitRemaining = [int64]$response.Headers.'X-Rate-Limit-Remaining'; # how many calls are remaining
      limitReset = [int64]$response.Headers.'X-Rate-Limit-Reset' # when limit will reset
    }
}

function Get-Error($_) {
    $responseStream = $_.Exception.Response.GetResponseStream()
    $responseReader = New-Object System.IO.StreamReader($responseStream)
    $responseContent = $responseReader.ReadToEnd()
    ConvertFrom-Json $responseContent
}
