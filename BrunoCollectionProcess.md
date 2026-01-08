# Bruno Collection Process

## Overview

Every repository with callable APIs includes a `/bruno` folder in the root directory containing API collections organized by controller.

## Collection Structure

The Bruno collections follow a standardized folder structure:

```text
└───Contoso - <API NAME>
    ├───environments/
    │   ├───LOCAL.bru
    │   ├───DEV.bru
    │   └───TST.bru
    ├───<Controller name 1>/
    │   └───<API name 1>.bru
    └───<Controller name 2>/
        └───<API name 2>.bru
```

### Example Structure

```text
└───Contoso - Experience
    ├───environments/
    │   ├───LOCAL.bru
    │   ├───MS DEV.bru
    │   └───MS TST.bru
    ├───Events/
    │   └───Get-Event-Detail.bru
    └───Shareholders/
        └───Get-Shareholders-Lite.bru
```

## Getting Started

### Opening a Collection

1. In Bruno, click on the `···` button and select `Open Collection` from dropdown.
   ![image.png](/images/OpeningCollection1.png)
1. Navigate to and select the appropriate `Contoso - <API NAME>` folder within the `/bruno` directory.
   ![image.png](/images/OpeningCollection2.png)

## Development Guidelines

### Pull Request Requirements

1. **Include Bruno files**: Add corresponding `.bru` files for any new APIs in your pull request
2. **Follow naming conventions**: Use descriptive names that match your API endpoints
3. **Organize by controller**: Place API files in folders named after their respective controllers
4. **Update environments**: Ensure all environments (LOCAL, DEV, TST) are properly configured

⚠️ **Security Warning**: _Never commit actual secrets, API keys, passwords, or sensitive data to the repository. Ensure all sensitive data is properly marked as secret in Bruno environment files._

![Bruno environment secret configuration](https://blog.usebruno.com/hs-fs/hubfs/image-png-Apr-04-2025-12-32-00-2023-PM.png?width=688&height=174&name=image-png-Apr-04-2025-12-32-00-2023-PM.png)

### File Naming Conventions

- Collection folders: `Contoso - <API NAME>`
- Controller folders: Use PascalCase matching your controller names.
  - Example: ShareholdersController -> Shareholders
- API files: Use same name as API to identify them easily.
  - Example: Get-Shareholders-Lite

## Automation

For automated creation of Bruno collections from Swagger/OpenAPI specifications, see the [Bruno Scaffolder Wiki](./README.md).
