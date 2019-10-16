param(
    [string] $organizationName = $env.organizationName,
    [string] $projectName = $env.projectName,
    [string] $personalAccessToken = $env.personalAccessToken,
    [string] $endpointType = $env.endpointType,
    [string] $urlForEndpoint = $env.urlForEndpoint,
    [string] $endpointName = $env.endpointName,
    [string] $pathBuildProperties = $env.pathBuildProperties,
    [string] $pathReleaseProperties = $env.pathReleaseProperties
)

Function getOrCreateEndpoint($organizationName, $projectName, $endPointName, $type, $url, $personalAccessToken, $headers) {

    $endPointUri = "https://dev.azure.com/$organizationName/$projectName/_apis/serviceendpoint/endpoints?endpointNames=$endPointName&api-version=5.1-preview.2"
    $endPointResults = Invoke-WebRequest -Method Get -Uri $endPointUri -Headers $headers
    $endPointResults = ($endPointResults.Content | ConvertFrom-Json)

    if ($endPointResults.count -eq 0) {
        Write-Host "Endpoint not found"
        $body = @{
            "name"          = $endPointName
            "type"          = $type
            "url"           = $url
            "authorization" = @{
                "scheme"     = "usernamePassword"
                "parameters"=@{
                    "username"= $personalAccessToken
                    "password"= ""
                }
            }
        } | ConvertTo-Json
        $endPointUri = "https://dev.azure.com/$organizationName/$projectName/_apis/serviceendpoint/endpoints?api-version=5.1-preview.2" 
        $endPointResult = Invoke-WebRequest -Method Post -Uri $endPointUri -Headers $headers -Body $body -ContentType "application/json"
        $endPointResultId = ($endPointResult | ConvertFrom-Json).Id 
    }
    else {
        Write-Host "Endpoint found"
        $endPointResultId = $endPointResults.value[0].id
    }
    return $endPointResultId
}

Function createBuild($organizationName, $projectName, $endpointId, $pathBuildProperties, $headers)
{
    $content = Get-Content $pathBuildProperties
    $content = $content.replace("{{endpointId}}",$endpointId)
    write-host "test : $content"
    $azureDevopsUri = "https://dev.azure.com/$organizationName/$projectName/_apis/build/definitions?api-version=5.1"
    Invoke-WebRequest -Method Post -Uri $azureDevopsUri -Headers $headers -Body $content -ContentType "application/json"
}

Function createRelease($organizationName, $projectName, $definitionUrl, $buildName,$definitionId,$projectId,$pathReleaseProperties, $headers)
{
    $content = Get-Content $pathReleaseProperties

    $content = $content.Replace("{{definitionUrl}}",$definitionUrl)
    $content = $content.Replace("{{buildName}}",$buildName)
    $content = $content.Replace("{{definitionId}}",$definitionId)
    $content = $content.Replace("{{projectId}}",$projectId)
    $content = $content.Replace("{{projectName}}",$projectName)
        
    $azureDevopsUri = "https://vsrm.dev.azure.com/$organizationName/$projectName/_apis/release/definitions?api-version=5.1"
    Invoke-WebRequest -Method Post -Uri $azureDevopsUri -Headers $headers -Body $content -ContentType "application/json"
}


$authentication = [Text.Encoding]::ASCII.GetBytes(":$personalAccessToken")
$authentication = [System.Convert]::ToBase64String($authentication)
$headers = @{
    Authorization = ("Basic {0}" -f $authentication)
}

$endPointResultId = getOrCreateEndpoint -organizationName $organizationName -projectName $projectName  -endPointName $endpointName -type $endpointType -url $urlForEndpoint -personalAccessToken $personalAccessToken -headers $headers

$build = createBuild -organizationName $organizationName -projectName $projectName -endpointId $endPointResultId -pathBuildProperties $pathBuildProperties -headers $headers

$resultAsJson = ($build.content | ConvertFrom-Json)

$linkProject = $resultAsJson._links.web.href

$definitionId = $linkProject.Split("=")[1]

$projectId = $resultAsJson.project.id

$buildName = $resultAsJson.name

createRelease -organizationName $organizationName -projectName $projectName  -definitionUrl $linkProject -buildName $buildName -definitionId $definitionId -projectId $projectId -pathReleaseProperties $pathReleaseProperties -headers $headers





