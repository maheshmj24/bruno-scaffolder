#Requires -Version 5.1

<#
.SYNOPSIS
    Bruno API Collection Scaffolder - Generates Bruno collection from Swagger/OpenAPI specification

.DESCRIPTION
    This script parses a Swagger/OpenAPI JSON file and generates a complete Bruno collection 
    following the organization's standardized structure with proper folder organization,
    environment files, and .bru API files.

.PARAMETER SwaggerPath
    Path to the swagger.json or OpenAPI JSON file

.PARAMETER OutputPath
    Directory where the Bruno collection will be created (default: ./bruno)

.PARAMETER ApiName
    Name of the API for the collection folder (e.g., "Experience", "UserManagement")

.PARAMETER CompanyName
    Company name for the collection (default: "Contoso")

.PARAMETER Environments
    Array of environment names to create (default: @("LOCAL", "DEV", "TST"))

.PARAMETER BaseUrls
    Hashtable of environment base URLs (optional)

.EXAMPLE
    .\Generate-BrunoCollection.ps1 -SwaggerPath ".\swagger.json" -ApiName "Experience"

.EXAMPLE
    .\Generate-BrunoCollection.ps1 -SwaggerPath ".\api-docs.json" -ApiName "UserService" -CompanyName "Fabrikam" -Environments @("LOCAL", "DEV", "STAGING", "PROD")

.NOTES
    Author: Bruno Scaffolder
    Version: 1.0
    Follows the organization's Bruno collection standards
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$SwaggerPath,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\bruno",
    
    [Parameter(Mandatory = $true)]
    [string]$ApiName,
    
    [Parameter(Mandatory = $false)]
    [string]$CompanyName = "Contoso",
    
    [Parameter(Mandatory = $false)]
    [string[]]$Environments = @("LOCAL", "DEV", "TST"),
    
    [Parameter(Mandatory = $false)]
    [hashtable]$BaseUrls = @{}
)

#region Helper Functions

# Color coding for output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { param([string]$Message) Write-ColorOutput $Message "Green" }
function Write-Info { param([string]$Message) Write-ColorOutput $Message "Cyan" }
function Write-Warning { param([string]$Message) Write-ColorOutput $Message "Yellow" }
function Write-Error { param([string]$Message) Write-ColorOutput $Message "Red" }

# Function to sanitize file and folder names
function Get-SanitizedName {
    param([string]$Name)
    
    # Remove invalid characters and convert to PascalCase
    $sanitized = $Name -replace '[^\w\s-]', '' -replace '\s+', ' '
    $words = $sanitized -split '[-\s_]' | Where-Object { $_ -ne '' }
    return ($words | ForEach-Object { 
            $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower() 
        }) -join ''
}

# Function to convert HTTP method and path to Bruno filename
function Get-BrunoFileName {
    param(
        [string]$Method,
        [string]$Path,
        [string]$OperationId
    )
    
    # First, try to extract the actual API name from the path
    # Look for patterns like "/Get-Something-Name/" or "/Get-Something-Name/{id}"
    if ($Path -match '/([A-Za-z]+-[A-Za-z-]+)(?:/|\{|$)') {
        $apiName = $Matches[1]
        # Clean up the API name (remove any trailing hyphens or invalid chars)
        $apiName = $apiName -replace '-+$', '' -replace '[^\w-]', ''
        if ($apiName -and $apiName -ne '') {
            return $apiName
        }
    }
    
    # If operationId exists, use it as fallback
    if ($OperationId) {
        return Get-SanitizedName $OperationId
    }
    
    # Final fallback: create name from method and path
    $pathParts = $Path -split '/' | Where-Object { $_ -ne '' -and $_ -notmatch '^\{.*\}$' }
    $methodName = $Method.Substring(0, 1).ToUpper() + $Method.Substring(1).ToLower()
    
    if ($pathParts.Count -gt 0) {
        $resourceName = ($pathParts | ForEach-Object { Get-SanitizedName $_ }) -join '-'
        
        # Check if path has parameters to make filename more specific
        if ($Path -match '\{[^}]+\}') {
            $paramParts = @()
            $regexMatches = [regex]::Matches($Path, '\{([^}]+)\}')
            foreach ($match in $regexMatches) {
                $paramName = Get-SanitizedName $match.Groups[1].Value
                $paramParts += $paramName
            }
            if ($paramParts.Count -gt 0) {
                $paramSuffix = ($paramParts -join '-')
                return "$methodName-$resourceName-By$paramSuffix"
            }
        }
        
        return "$methodName-$resourceName"
    }
    
    return "$methodName-Request"
}

# Function to extract controller name from path or tags
function Get-ControllerName {
    param(
        [string]$Path,
        [array]$Tags,
        [string]$OperationId
    )
    
    # Try to get from tags first - use the tag name as-is
    if ($Tags -and $Tags.Count -gt 0) {
        return $Tags[0]  # Use the original tag name without modification
    }
    
    # Try to extract from operationId (e.g., "UsersController_GetUser" -> "Users")
    if ($OperationId -and $OperationId -match '^(\w+)Controller_') {
        return Get-SanitizedName $Matches[1]
    }
    
    # Fallback: use first segment of path
    $pathSegments = $Path -split '/' | Where-Object { $_ -ne '' -and $_ -notmatch '^\{.*\}$' }
    if ($pathSegments.Count -gt 0) {
        return Get-SanitizedName $pathSegments[0]
    }
    
    return "General"
}

# Function to create Bruno environment file
function New-BrunoEnvironment {
    param(
        [string]$Name,
        [string]$BaseUrl,
        [string]$FilePath
    )
    
    $envContent = @"
vars {
  baseUrl: $BaseUrl
}
vars:secret [

]
"@
    
    $envContent | Out-File -FilePath $FilePath -Encoding UTF8
}

# Function to create Bruno collection.bru file
function New-BrunoCollectionFile {
    param(
        [string]$CollectionName,
        [string]$FilePath
    )
    
    $collectionContent = @"
meta {
  name: $CollectionName
  type: collection
}
"@
    
    $collectionContent | Out-File -FilePath $FilePath -Encoding UTF8
}

# Function to create Bruno folder.bru file
function New-BrunoFolderFile {
    param(
        [string]$FolderName,
        [string]$FilePath
    )
    
    $folderContent = @"
meta {
  name: $FolderName
  type: folder
}
"@
    
    $folderContent | Out-File -FilePath $FilePath -Encoding UTF8
}

# Function to load configuration from JSON file
function Get-BrunoScaffolderConfig {
    param([string]$ConfigPath)
    
    $defaultConfig = @{
        defaultCompanyName  = "Contoso"
        defaultEnvironments = @("LOCAL", "DEV", "TST")
        defaultBaseUrls     = @{
            "LOCAL" = "https://localhost:5001/api"
            "DEV"   = "https://api-dev.contoso.com"
            "TST"   = "https://api-test.contoso.com"
        }
        apiNamingRules      = @{
            removePrefixes = @("API", "Service", "Controller")
            removeSuffixes = @("API", "Service", "Controller")
            usePascalCase  = $true
        }
    }
    
    if (Test-Path $ConfigPath) {
        try {
            $jsonConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            return $jsonConfig
        }
        catch {
            Write-Warning "Failed to load config file '$ConfigPath'. Using defaults."
            return $defaultConfig
        }
    }
    else {
        Write-Info "Config file not found. Using default configuration."
        return $defaultConfig
    }
}

#region JSON Schema Processing

# Function to generate JSON body from Swagger schema
function Get-JsonBodyFromSchema {
    param(
        [object]$Schema,
        [object]$SwaggerContent
    )
    
    if (-not $Schema) { return $null }
    
    # Handle schema references
    if ($Schema.'$ref') {
        $refPath = $Schema.'$ref' -replace '#/', '' -replace '/', '.'
        $refParts = $refPath -split '\.'
        $resolvedSchema = $SwaggerContent
        foreach ($part in $refParts) {
            $resolvedSchema = $resolvedSchema.$part
        }
        return Get-JsonBodyFromSchema -Schema $resolvedSchema -SwaggerContent $SwaggerContent
    }
    
    switch ($Schema.type) {
        'object' {
            $obj = @{}
            if ($Schema.properties) {
                foreach ($prop in $Schema.properties.PSObject.Properties) {
                    $propName = $prop.Name
                    $propSchema = $prop.Value
                    $obj[$propName] = Get-JsonBodyFromSchema -Schema $propSchema -SwaggerContent $SwaggerContent
                }
            }
            return $obj
        }
        'array' {
            # Generate sample item for arrays with schema references
            if ($Schema.items) {
                $sampleItem = Get-JsonBodyFromSchema -Schema $Schema.items -SwaggerContent $SwaggerContent
                if ($sampleItem) {
                    return @($sampleItem)
                }
            }
            return @()
        }
        'string' { return "{{PLACEHOLDER}}" }
        'integer' { return 0 }
        'number' { return 0.0 }
        'boolean' { return $false }
        default { return "{{PLACEHOLDER}}" }
    }
}

#endregion

#region Bruno File Generation

function New-BrunoApiFile {
    param(
        [string]$Method,
        [string]$Path,
        [string]$Summary,
        [string]$Description,
        [hashtable]$Parameters,
        [object]$RequestBody,
        [object]$SwaggerContent,
        [string]$FilePath
    )
    
    $method = $Method.ToLower()
    $url = "{{baseUrl}}$Path"
    
    # Replace path parameters with Bruno variable syntax
    if ($Parameters -and $Parameters.ContainsKey('path')) {
        foreach ($param in $Parameters['path']) {
            $paramName = $param.name
            $url = $url -replace "\{$paramName\}", "{{$paramName}}"
        }
    }
    
    $content = @"
meta {
  name: $Summary
  type: http
  seq: 1
}

$method {
  url: $url
  body: none
  auth: inherit
}
"@

    # Add query parameters
    if ($Parameters -and $Parameters.ContainsKey('query') -and $Parameters['query'].Count -gt 0) {
        $content += "`n`nparams:query {`n"
        foreach ($param in $Parameters['query']) {
            $required = if ($param.required) { "" } else { "~" }
            $content += "  $required$($param.name): {{PLACEHOLDER}}`n"
        }
        $content += "}`n"
    }
    
    # Add headers
    if ($Parameters -and $Parameters.ContainsKey('header') -and $Parameters['header'].Count -gt 0) {
        $content += "`nheaders {`n"
        foreach ($param in $Parameters['header']) {
            $content += "  $($param.name): {{PLACEHOLDER}}`n"
        }
        $content += "}`n"
    }
    
    # Add request body for POST/PUT/PATCH
    if ($RequestBody -and $method -in @('post', 'put', 'patch')) {
        $content = $content -replace 'body: none', 'body: json'
        $content += "`nbody:json {`n"
        
        # Try to generate JSON from schema
        $jsonBody = $null
        if ($RequestBody.content) {
            $contentTypes = @('application/json', 'application/*+json', 'text/json')
            foreach ($contentType in $contentTypes) {
                if ($RequestBody.content.$contentType -and $RequestBody.content.$contentType.schema) {
                    $schema = $RequestBody.content.$contentType.schema
                    $jsonObj = Get-JsonBodyFromSchema -Schema $schema -SwaggerContent $SwaggerContent
                    if ($jsonObj) {
                        # Convert to JSON with proper array handling
                        $jsonString = $jsonObj | ConvertTo-Json -Depth 10 -Compress:$false
                        
                        # Fix single-element array issue in PowerShell JSON conversion
                        # Look for properties that should be arrays but aren't formatted as such
                        if ($schema.'$ref') {
                            $refPath = $schema.'$ref' -replace '#/', '' -replace '/', '.'
                            $refParts = $refPath -split '\.'
                            $resolvedSchema = $SwaggerContent
                            foreach ($part in $refParts) {
                                $resolvedSchema = $resolvedSchema.$part
                            }
                            $actualSchema = $resolvedSchema
                        }
                        else {
                            $actualSchema = $schema
                        }
                        
                        # Post-process JSON to fix array formatting for known array properties
                        if ($actualSchema.properties) {
                            foreach ($prop in $actualSchema.properties.PSObject.Properties) {
                                if ($prop.Value.type -eq 'array' -and $prop.Value.items) {
                                    $propName = $prop.Name
                                    # Use a more robust approach for nested object arrays
                                    $lines = $jsonString -split "`r?`n"
                                    $result = @()
                                    $i = 0
                                    
                                    while ($i -lt $lines.Count) {
                                        $line = $lines[$i]
                                        if ($line -match "`"$propName`":\s*\{") {
                                            # Found the array property that needs fixing
                                            $result += $line -replace "(`"$propName`":\s*)\{", "`$1[{"
                                            $i++
                                            $braceCount = 1
                                            
                                            # Process until we close the object
                                            while ($i -lt $lines.Count -and $braceCount -gt 0) {
                                                $currentLine = $lines[$i]
                                                $openBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                                                $closeBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                                                $braceCount += $openBraces - $closeBraces
                                                
                                                if ($braceCount -eq 0) {
                                                    $result += $currentLine -replace '^(\s*)\}(\s*)(,?)$', '$1}]$2$3'
                                                }
                                                else {
                                                    $result += $currentLine
                                                }
                                                $i++
                                            }
                                        }
                                        else {
                                            $result += $line
                                            $i++
                                        }
                                    }
                                    
                                    $jsonString = $result -join "`n"
                                }
                            }
                        }
                        
                        $jsonBody = $jsonString
                        break
                    }
                }
            }
        }
        
        if ($jsonBody) {
            # Format the JSON nicely with proper indentation
            $formattedJson = $jsonBody -split "`n" | ForEach-Object { "  $_" }
            $content += $formattedJson -join "`n"
        }
        else {
            $content += "  {`n    `"example`": `"{{PLACEHOLDER}}`"`n  }"
        }
        
        $content += "`n}`n"
    }
    
    # Add path variables section if any
    if ($Parameters -and $Parameters.ContainsKey('path') -and $Parameters['path'].Count -gt 0) {
        $content += "`nvars:pre-request {`n"
        foreach ($param in $Parameters['path']) {
            $content += "  $($param.name): {{PLACEHOLDER}}`n"
        }
        $content += "}`n"
    }
    
    # Add settings block
    $content += "`nsettings {`n  encodeUrl: true`n  timeout: 0`n}`n"
    
    $content | Out-File -FilePath $FilePath -Encoding UTF8
}

#endregion

#region Main Execution

# Main execution
try {
    Write-Info "🚀 Starting Bruno Collection Scaffolder"
    
    # Load configuration
    $configPath = Join-Path $PSScriptRoot "bruno-scaffolder-config.json"
    $config = Get-BrunoScaffolderConfig -ConfigPath $configPath
    
    # Use config defaults if parameters not provided
    if (-not $CompanyName -or $CompanyName -eq "Contoso") {
        $CompanyName = $config.defaultCompanyName
    }
    if (-not $Environments -or ($Environments.Count -eq 3 -and $Environments[0] -eq "LOCAL")) {
        $Environments = $config.defaultEnvironments
    }
    if (-not $BaseUrls -or $BaseUrls.Count -eq 0) {
        $BaseUrls = @{}
        $config.defaultBaseUrls.PSObject.Properties | ForEach-Object {
            $BaseUrls[$_.Name] = $_.Value
        }
    }
    
    Write-Info "Reading Swagger file: $SwaggerPath"
    
    # Read and parse Swagger JSON
    $swaggerContent = Get-Content -Path $SwaggerPath -Raw | ConvertFrom-Json
    
    # Create collection structure
    $collectionName = "$CompanyName - $ApiName"
    $collectionPath = Join-Path $OutputPath $collectionName
    
    Write-Info "Creating collection: $collectionName"
    
    # Create main collection directory
    if (Test-Path $collectionPath) {
        Write-Warning "Collection directory already exists. Contents will be merged/overwritten."
    }
    New-Item -Path $collectionPath -ItemType Directory -Force | Out-Null
    
    # Create environments directory and files
    $environmentsPath = Join-Path $collectionPath "environments"
    New-Item -Path $environmentsPath -ItemType Directory -Force | Out-Null
    
    Write-Info "Creating environment files..."
    foreach ($env in $Environments) {
        $envFileName = "$env.bru"
        $envFilePath = Join-Path $environmentsPath $envFileName
        
        # Use provided base URL or create placeholder
        $baseUrl = if ($BaseUrls.ContainsKey($env)) {
            $BaseUrls[$env]
        }
        elseif ($swaggerContent.host -and $swaggerContent.basePath) {
            "https://$($swaggerContent.host)$($swaggerContent.basePath)"
        }
        elseif ($swaggerContent.servers -and $swaggerContent.servers.Count -gt 0) {
            $swaggerContent.servers[0].url
        }
        else {
            "https://api.example.com/v1"
        }
        
        New-BrunoEnvironment -Name $env -BaseUrl $baseUrl -FilePath $envFilePath
        Write-Success "  ✓ Created $envFileName"
    }
    
    # Parse API paths and create .bru files
    Write-Info "Processing API endpoints..."
    $controllerStats = @{}
    $totalEndpoints = 0
    
    foreach ($pathKey in $swaggerContent.paths.PSObject.Properties.Name) {
        $pathObj = $swaggerContent.paths.$pathKey
        
        foreach ($methodKey in $pathObj.PSObject.Properties.Name) {
            if ($methodKey -in @('get', 'post', 'put', 'delete', 'patch', 'options', 'head')) {
                $operation = $pathObj.$methodKey
                $totalEndpoints++
                
                # Determine controller/folder name
                $controllerName = Get-ControllerName -Path $pathKey -Tags $operation.tags -OperationId $operation.operationId
                
                # Create controller directory if it doesn't exist
                $controllerPath = Join-Path $collectionPath $controllerName
                if (!(Test-Path $controllerPath)) {
                    New-Item -Path $controllerPath -ItemType Directory -Force | Out-Null
                    
                    # Create folder.bru file in the controller directory
                    $folderBruPath = Join-Path $controllerPath "folder.bru"
                    New-BrunoFolderFile -FolderName $controllerName -FilePath $folderBruPath
                    
                    $controllerStats[$controllerName] = 0
                }
                $controllerStats[$controllerName]++
                
                # Generate .bru file
                $fileName = Get-BrunoFileName -Method $methodKey -Path $pathKey -OperationId $operation.operationId
                $bruFilePath = Join-Path $controllerPath "$fileName.bru"
                
                # Parse parameters
                $parameters = @{
                    'path'   = @()
                    'query'  = @()
                    'header' = @()
                }
                
                if ($operation.parameters) {
                    foreach ($param in $operation.parameters) {
                        if ($param.in -in @('path', 'query', 'header')) {
                            $parameters[$param.in] += $param
                        }
                    }
                }
                
                # Create the .bru file - use filename as the meta name instead of summary
                New-BrunoApiFile -Method $methodKey -Path $pathKey -Summary $fileName -Description $operation.description -Parameters $parameters -RequestBody $operation.requestBody -SwaggerContent $swaggerContent -FilePath $bruFilePath
                
                Write-Success "  ✓ Created $controllerName/$fileName.bru"
            }
        }
    }
    
    # Create collection configuration file
    $collectionConfig = @"
{
  "version": "1",
  "name": "$collectionName",
  "type": "collection",
  "ignore": [
    "node_modules",
    ".git"
  ]
}
"@
    
    $configPath = Join-Path $collectionPath "bruno.json"
    $collectionConfig | Out-File -FilePath $configPath -Encoding UTF8
    
    # Summary
    Write-Success "`n🎉 Bruno collection created successfully!"
    Write-Info "📊 Summary:"
    Write-Info "   Collection: $collectionName"
    Write-Info "   Location: $collectionPath"
    Write-Info "   Environments: $($Environments.Count) ($($Environments -join ', '))"
    Write-Info "   Controllers: $($controllerStats.Count)"
    Write-Info "   Total Endpoints: $totalEndpoints"
    
    Write-Info "`n📁 Controller breakdown:"
    foreach ($controller in $controllerStats.GetEnumerator() | Sort-Object Name) {
        Write-Info "   $($controller.Name): $($controller.Value) endpoints"
    }
    
    Write-Info "`n🎯 Next steps:"
    Write-Info "   1. Open Bruno and select 'Open Collection'"
    Write-Info "   2. Navigate to: $collectionPath"
    Write-Info "   3. Configure environment variables as needed"
    Write-Info "   4. Review and test the generated API calls"
    Write-Info "   5. Commit to your repository following your organization's guidelines"
    
}
catch {
    Write-Error "❌ An error occurred: $($_.Exception.Message)"
    Write-Error $_.Exception.StackTrace
    exit 1
}

#endregion