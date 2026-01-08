# Example Usage Guide

## Basic Usage

### Using PowerShell Script Directly

```powershell
# Basic usage with required parameters
.\Generate-BrunoCollection.ps1 -SwaggerPath ".\swagger.json" -ApiName "Experience"

# With custom output path
.\Generate-BrunoCollection.ps1 -SwaggerPath ".\api-docs.json" -ApiName "UserService" -OutputPath ".\my-bruno-collections"

# With custom company name and environments
.\Generate-BrunoCollection.ps1 -SwaggerPath ".\swagger.json" -ApiName "PaymentService" -CompanyName "Fabrikam" -Environments @("LOCAL", "DEV", "STAGING", "PROD")

# With custom base URLs
$baseUrls = @{
    "LOCAL" = "https://localhost:5001/api"
    "DEV" = "https://dev-api.mycompany.com"
    "PROD" = "https://api.mycompany.com"
}
.\Generate-BrunoCollection.ps1 -SwaggerPath ".\swagger.json" -ApiName "Experience" -BaseUrls $baseUrls
```

## Sample Output Structure

After running the scaffolder with the sample swagger file, you'll get:

```
bruno/
└── Contoso - Experience/
    ├── bruno.json
    ├── environments/
    │   ├── LOCAL.bru
    │   ├── DEV.bru
    │   └── TST.bru
    ├── Events/
    │   ├── folder.bru
    │   └── Geteventdetail.bru
    └── Shareholders/
        ├── folder.bru
        ├── Getshareholderslite.bru
        └── Updateshareholder.bru
```

## Testing the Example

1. Run the scaffolder with the sample file:

   ```powershell
   .\Generate-BrunoCollection.ps1 -SwaggerPath ".\examples\sample-swagger.json" -ApiName "Experience"
   ```

2. Open Bruno and load the generated collection

3. Configure your environment variables and test the endpoints

## Customization Tips

- Modify `bruno-scaffolder-config.json` for organization defaults
- The script automatically handles path parameters, query parameters, and headers
- Controller names are derived from Swagger tags or paths
- File names are based on operationId or generated from HTTP method + path
