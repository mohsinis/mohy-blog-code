<#
.SYNOPSIS
    Automated Terraform deployment script for Azure Databricks infrastructure across multiple environments.

.DESCRIPTION
    This PowerShell script automates the deployment of Azure Databricks infrastructure using Terraform.
    It handles authentication, subscription management, subnet delegation validation/fixes, and executes
    Terraform commands with environment-specific configurations.

    WHAT THIS SCRIPT DOES:
    ======================
    1. Loads Azure credentials from azure-auth.env file
    2. Sets the correct Azure subscription based on environment (dev/test/stage/analytics/poc)
    3. Authenticates with Azure using service principal
    4. Validates and fixes subnet delegations required for Databricks:
       - Databricks public & private subnets MUST be delegated to Microsoft.Databricks/workspaces
       - Private endpoint subnet MUST NOT have any delegation
    5. Executes the requested Terraform command (init/plan/apply/destroy/validate/fmt/show)
    6. Reports results and state file location

    WORKFLOW STEPS:
    ==============
    Step 1: Load authentication credentials from azure-auth.env
    Step 2: Set Terraform environment variables
    Step 3: Select the correct Azure subscription for the target environment
    Step 4: Authenticate with Azure CLI using service principal
    Step 5: Switch Azure CLI context to the target subscription
    Step 6: Check and fix subnet delegations (unless -SkipSubnetCheck is used)
    Step 7: Execute the requested Terraform command
    Step 8: Report success or failure with state file details

    KEY FEATURES:
    ============
    - Multi-environment support with isolated state files
    - Automatic subnet delegation validation and fixing
    - Environment-specific subscription management
    - Comprehensive error handling and reporting
    - Color-coded output for easy reading
    - Safe destroy operation with confirmation prompt

.PARAMETER Environment
    The target environment for deployment. Valid values: dev, test, stage, analytics, poc
    Each environment maps to its own Azure subscription and state file.

.PARAMETER Action
    The Terraform action to perform:
    - init     : Initialize Terraform with environment-specific backend
    - plan     : Preview changes without applying them
    - apply    : Apply the Terraform configuration
    - destroy  : Destroy all infrastructure (requires confirmation)
    - validate : Validate Terraform syntax
    - fmt      : Format Terraform files
    - show     : Display current state

.PARAMETER SkipSubnetCheck
    Optional switch to skip the automatic subnet delegation check and fix.
    Use this only if you're certain subnet delegations are correct.

.EXAMPLE
    .\deploy.ps1 -Environment test -Action plan
    Preview changes for the test environment

.EXAMPLE
    .\deploy.ps1 -Environment analytics -Action apply
    Deploy infrastructure to the analytics environment

.EXAMPLE
    .\deploy.ps1 -Environment dev -Action init
    Initialize Terraform for the dev environment

.NOTES
    Author: Your Name
    Prerequisites:
    - Azure CLI installed and accessible
    - Terraform installed
    - azure-auth.env file configured with service principal credentials
    - Existing VNet and subnets in Azure
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "test", "stage", "analytics", "poc")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet("init", "plan", "apply", "destroy", "validate", "fmt", "show")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSubnetCheck
)

# =============================================================================
# STEP 1: Display Script Parameters
# =============================================================================
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "Action: $Action" -ForegroundColor Green

# =============================================================================
# STEP 2: Load Authentication Credentials
# =============================================================================
# Load Azure service principal credentials from azure-auth.env file
# This file contains ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, and
# environment-specific subscription IDs (ARM_SUBSCRIPTION_ID_DEV, etc.)
Write-Host "Setting up Azure environment variables..." -ForegroundColor Yellow
# Parse azure-auth.env file and load all environment variables
# The file uses bash export syntax: export VAR_NAME="value"
# This regex extracts the variable name and value and sets them as PowerShell environment variables
if (Test-Path "azure-auth.env") {
    Get-Content "azure-auth.env" | ForEach-Object {
        # Match lines like: export ARM_CLIENT_ID="12345-67890-abcdef"
        if ($_ -match '^export\s+([^=]+)="?([^"]*)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            Set-Item -Path "env:$varName" -Value $varValue
            Write-Host "Set $varName" -ForegroundColor Gray
        }
    }
    Write-Host "Environment variables loaded" -ForegroundColor Green
} else {
    Write-Host "ERROR: azure-auth.env file not found" -ForegroundColor Red
    Write-Host "Please create azure-auth.env with your Azure credentials" -ForegroundColor Yellow
    exit 1
}

# =============================================================================
# STEP 3: Set Terraform Variables
# =============================================================================
# Pass the environment parameter to Terraform as TF_VAR_environment
# Terraform will automatically pick up any environment variables prefixed with TF_VAR_
$env:TF_VAR_environment = $Environment

# =============================================================================
# STEP 4: Select Correct Azure Subscription
# =============================================================================
# Each environment has its own subscription defined in azure-auth.env
# For example: ARM_SUBSCRIPTION_ID_DEV, ARM_SUBSCRIPTION_ID_TEST, etc.
Write-Host "Setting environment-specific Azure subscription..." -ForegroundColor Yellow
# Construct the environment-specific subscription variable name
# Example: If Environment = "dev", then envVarName = "ARM_SUBSCRIPTION_ID_DEV"
$envVarName = "ARM_SUBSCRIPTION_ID_$($Environment.ToUpper())"
$subscriptionId = Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value

# Verify the subscription ID exists
if (-not $subscriptionId) {
    Write-Host "ERROR: Environment variable $envVarName not found in azure-auth.env" -ForegroundColor Red
    Write-Host "Please ensure azure-auth.env contains: export $envVarName=\"your-subscription-id\"" -ForegroundColor Yellow
    exit 1
}

# Map environment to subscription name for display purposes
$subscriptionName = switch ($Environment) {
    "dev" { "contoso-dev-sub" }
    "test" { "contoso-test-sub" }
    "stage" { "contoso-stage-sub" }
    "analytics" { "contoso-analytics-sub" }
    "poc" { "contoso-poc-sub" }
    default { "contoso-$Environment-sub" }
}

# =============================================================================
# STEP 5: Set Active Subscription
# =============================================================================
# Override ARM_SUBSCRIPTION_ID with the environment-specific value
# This ensures Terraform uses the correct subscription
$env:ARM_SUBSCRIPTION_ID = $subscriptionId
Write-Host "Set subscription to: $subscriptionName ($subscriptionId)" -ForegroundColor Green

# =============================================================================
# STEP 6: Authenticate with Azure
# =============================================================================
# Use Azure CLI to authenticate with the service principal
# This allows the script to make Azure API calls (e.g., for subnet checks)
Write-Host "Authenticating with Azure..." -ForegroundColor Yellow
# Login using service principal credentials loaded from azure-auth.env
az login --service-principal -u $env:ARM_CLIENT_ID -p $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Azure authentication successful" -ForegroundColor Green
    
    # =============================================================================
    # STEP 7: Switch Azure CLI Context to Target Subscription
    # =============================================================================
    # Azure CLI needs to be set to the correct subscription for subnet checks
    # This is separate from the Terraform ARM_SUBSCRIPTION_ID variable
    Write-Host "Switching to subscription: $subscriptionName..." -ForegroundColor Yellow
    az account set --subscription $subscriptionId
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully switched to subscription: $subscriptionName ($subscriptionId)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed to switch to subscription: $subscriptionName ($subscriptionId)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Azure authentication failed" -ForegroundColor Red
    Write-Host "Check your credentials in azure-auth.env" -ForegroundColor Yellow
    exit 1
}

# =============================================================================
# FUNCTION: Test-And-Fix-SubnetDelegations
# =============================================================================
# This function validates and fixes subnet delegations required for Databricks
# 
# Azure Databricks requires specific subnet delegations:
# - Public & Private subnets MUST be delegated to Microsoft.Databricks/workspaces
# - Private Endpoint subnet MUST NOT have any delegation
#
# The function:
# 1. Checks current delegation status of all three subnets
# 2. Identifies any issues
# 3. Automatically fixes delegation issues using Azure CLI
# 4. Returns true if successful, false if fixes failed
#
# Parameters:
#   $Environment - The target environment (dev, test, stage, analytics, poc)
#
# Returns:
#   Boolean - True if delegations are correct or successfully fixed, False otherwise
# =============================================================================
function Test-And-Fix-SubnetDelegations {
    param([string]$Environment)
    
    Write-Host ""
    Write-Host "=" -NoNewline -ForegroundColor Cyan
    Write-Host ("=" * 79) -ForegroundColor Cyan
    Write-Host "Checking Subnet Delegations" -ForegroundColor Cyan
    Write-Host "=" -NoNewline -ForegroundColor Cyan
    Write-Host ("=" * 79) -ForegroundColor Cyan
    Write-Host ""
    
    # Define subnet names based on environment naming convention
    $vnetName = "contoso-$Environment-cc-vnet-01"
    $vnetRgName = "contoso-$Environment-cc-vnet-rg-01"
    $publicSubnetName = "contoso-$Environment-databricks-public-snet-01"
    $privateSubnetName = "contoso-$Environment-databricks-private-snet-01"
    $pepSubnetName = "contoso-$Environment-pep-snet-01"
    
    $needsFix = $false
    
    # =========================================================================
    # Check Databricks Public Subnet
    # =========================================================================
    # Query Azure to get the current delegation for the public subnet
    # Expected: Microsoft.Databricks/workspaces
    Write-Host "Checking $publicSubnetName..." -ForegroundColor Yellow
    $publicDelegation = az network vnet subnet show `
        --resource-group $vnetRgName `
        --vnet-name $vnetName `
        --name $publicSubnetName `
        --query "delegations[0].serviceName" -o tsv 2>$null
    
    if ($publicDelegation -ne "Microsoft.Databricks/workspaces") {
        Write-Host "   WARNING: Missing Databricks delegation" -ForegroundColor Yellow
        $needsFix = $true
    } else {
        Write-Host "   [OK] Databricks delegation found" -ForegroundColor Green
    }
    
    # =========================================================================
    # Check Databricks Private Subnet
    # =========================================================================
    # Query Azure to get the current delegation for the private subnet
    # Expected: Microsoft.Databricks/workspaces
    Write-Host "Checking $privateSubnetName..." -ForegroundColor Yellow
    $privateDelegation = az network vnet subnet show `
        --resource-group $vnetRgName `
        --vnet-name $vnetName `
        --name $privateSubnetName `
        --query "delegations[0].serviceName" -o tsv 2>$null
    
    if ($privateDelegation -ne "Microsoft.Databricks/workspaces") {
        Write-Host "   WARNING: Missing Databricks delegation" -ForegroundColor Yellow
        $needsFix = $true
    } else {
        Write-Host "   [OK] Databricks delegation found" -ForegroundColor Green
    }
    
    # =========================================================================
    # Check Private Endpoint Subnet
    # =========================================================================
    # Private endpoint subnets should NOT have any delegation
    # Having a delegation will cause deployment failures
    Write-Host "Checking $pepSubnetName..." -ForegroundColor Yellow
    $pepDelegation = az network vnet subnet show `
        --resource-group $vnetRgName `
        --vnet-name $vnetName `
        --name $pepSubnetName `
        --query "delegations[0].serviceName" -o tsv 2>$null
    
    if ($pepDelegation) {
        Write-Host "   WARNING: Has delegation (should have none)" -ForegroundColor Yellow
        $needsFix = $true
    } else {
        Write-Host "   [OK] No delegation (correct)" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # =========================================================================
    # Apply Fixes if Needed
    # =========================================================================
    if ($needsFix) {
        Write-Host "Fixing subnet delegations..." -ForegroundColor Yellow
        Write-Host ""
        
        # Fix public subnet - Add Databricks delegation
        if ($publicDelegation -ne "Microsoft.Databricks/workspaces") {
            Write-Host "   Updating $publicSubnetName..." -ForegroundColor Yellow
            az network vnet subnet update `
                --resource-group $vnetRgName `
                --vnet-name $vnetName `
                --name $publicSubnetName `
                --delegations Microsoft.Databricks/workspaces `
                --output none
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [SUCCESS] Public subnet delegation added" -ForegroundColor Green
            } else {
                Write-Host "   [ERROR] Failed to add public subnet delegation" -ForegroundColor Red
                return $false
            }
        }
        
        # Fix private subnet - Add Databricks delegation
        if ($privateDelegation -ne "Microsoft.Databricks/workspaces") {
            Write-Host "   Updating $privateSubnetName..." -ForegroundColor Yellow
            az network vnet subnet update `
                --resource-group $vnetRgName `
                --vnet-name $vnetName `
                --name $privateSubnetName `
                --delegations Microsoft.Databricks/workspaces `
                --output none
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [SUCCESS] Private subnet delegation added" -ForegroundColor Green
            } else {
                Write-Host "   [ERROR] Failed to add private subnet delegation" -ForegroundColor Red
                return $false
            }
        }
        
        # Fix PEP subnet - Remove any delegation
        if ($pepDelegation) {
            Write-Host "   Updating $pepSubnetName..." -ForegroundColor Yellow
            az network vnet subnet update `
                --resource-group $vnetRgName `
                --vnet-name $vnetName `
                --name $pepSubnetName `
                --remove delegations `
                --output none
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   [SUCCESS] PEP subnet delegation removed" -ForegroundColor Green
            } else {
                Write-Host "   WARNING: Could not remove PEP subnet delegation" -ForegroundColor Yellow
                Write-Host "   This may need manual intervention" -ForegroundColor Yellow
            }
        }
        
        Write-Host ""
        Write-Host "Subnet delegations fixed successfully" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "All subnet delegations are correct" -ForegroundColor Green
        Write-Host ""
    }
    
    return $true
}

# =============================================================================
# STEP 8: Execute Terraform Commands
# =============================================================================
Write-Host "Executing Terraform $Action for $Environment environment..." -ForegroundColor Cyan
Write-Host "State file: $Environment.tfstate" -ForegroundColor Gray

switch ($Action) {
    "init" {
        # =====================================================================
        # INIT: Initialize Terraform Backend
        # =====================================================================
        # Configures Terraform to use Azure Storage for state file management
        # Each environment has its own .tfbackend file with unique state file
        # Flags:
        #   -backend-config : Specifies environment-specific backend config
        #   -reconfigure    : Reconfigure backend (useful when switching envs)
        #   -upgrade        : Upgrade provider versions to latest allowed
        Write-Host "Initializing Terraform with $Environment backend..." -ForegroundColor Yellow
        terraform init -backend-config="backend-configs/$Environment.tfbackend" -reconfigure -upgrade
    }
    "plan" {
        # =====================================================================
        # PLAN: Preview Infrastructure Changes
        # =====================================================================
        # Shows what Terraform will create/modify/destroy without actually
        # making any changes. Saves the plan to a file for apply command.
        
        # Check subnet delegations before planning
        if (-not $SkipSubnetCheck) {
            $delegationCheck = Test-And-Fix-SubnetDelegations -Environment $Environment
            if (-not $delegationCheck) {
                Write-Host "ERROR: Subnet delegation fix failed. Please fix manually and retry." -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "Planning Terraform changes for $Environment..." -ForegroundColor Yellow
        # Generate and save plan to environment-specific plan file
        terraform plan -var="environment=$Environment" -out="$Environment.tfplan"
    }
    "apply" {
        # =====================================================================
        # APPLY: Deploy Infrastructure
        # =====================================================================
        # Applies the Terraform configuration to create/modify/destroy resources
        # Preference: Use saved plan file from 'plan' command
        # Fallback: Apply directly with auto-approve if no plan file exists
        
        # Check and fix subnet delegations before applying
        if (-not $SkipSubnetCheck) {
            $delegationCheck = Test-And-Fix-SubnetDelegations -Environment $Environment
            if (-not $delegationCheck) {
                Write-Host "ERROR: Subnet delegation fix failed. Please fix manually and retry." -ForegroundColor Red
                exit 1
            }
        }
        
        Write-Host "Applying Terraform changes for $Environment..." -ForegroundColor Yellow
        if (Test-Path "$Environment.tfplan") {
            # Apply the saved plan file (preferred method)
            terraform apply "$Environment.tfplan"
            # Clean up the plan file after successful apply
            Remove-Item "$Environment.tfplan" -Force
        } else {
            # No plan file found, apply directly (not recommended for production)
            Write-Host "WARNING: No plan file found. Running apply with auto-approve..." -ForegroundColor Yellow
            terraform apply -var="environment=$Environment" -auto-approve
        }
    }
    "destroy" {
        # =====================================================================
        # DESTROY: Delete All Infrastructure
        # =====================================================================
        # Destroys all resources managed by Terraform for this environment
        # Requires explicit confirmation to prevent accidental deletion
        Write-Host "Destroying Terraform resources for $Environment..." -ForegroundColor Red
        Write-Host "WARNING: This will destroy all resources in $Environment environment!" -ForegroundColor Red
        Write-Host "This includes:" -ForegroundColor Red
        Write-Host "  - Databricks workspace" -ForegroundColor Red
        Write-Host "  - Storage accounts and all data" -ForegroundColor Red
        Write-Host "  - Private endpoints" -ForegroundColor Red
        Write-Host "  - Access connectors" -ForegroundColor Red
        $confirm = Read-Host "Are you sure? Type 'yes' to continue"
        if ($confirm -eq "yes") {
            terraform destroy -var="environment=$Environment" -auto-approve
        } else {
            Write-Host "Destroy cancelled" -ForegroundColor Yellow
            exit 1
        }
    }
    "validate" {
        # =====================================================================
        # VALIDATE: Check Terraform Syntax
        # =====================================================================
        # Validates the Terraform configuration files for syntax errors
        # Does not check if the configuration is deployable or valid for Azure
        Write-Host "Validating Terraform configuration..." -ForegroundColor Yellow
        terraform validate
    }
    "fmt" {
        # =====================================================================
        # FMT: Format Terraform Files
        # =====================================================================
        # Automatically formats all .tf files to follow Terraform style conventions
        # Uses -recursive to format files in all subdirectories
        Write-Host "Formatting Terraform files..." -ForegroundColor Yellow
        terraform fmt -recursive
    }
    "show" {
        # =====================================================================
        # SHOW: Display Current State
        # =====================================================================
        # Shows the current state of deployed resources
        # Useful for inspecting what's actually deployed
        Write-Host "Showing Terraform state for $Environment..." -ForegroundColor Yellow
        terraform show
    }
}

# =============================================================================
# STEP 9: Report Results
# =============================================================================

# Check if Terraform command was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=" -NoNewline -ForegroundColor Green
    Write-Host ("=" * 79) -ForegroundColor Green
    Write-Host "SUCCESS: Terraform $Action completed for $Environment environment" -ForegroundColor Green
    Write-Host "=" -NoNewline -ForegroundColor Green
    Write-Host ("=" * 79) -ForegroundColor Green
    Write-Host ""
    
    # Display remote state file location for reference
    Write-Host "State file location:" -ForegroundColor Cyan
    Write-Host "   Storage Account: contosoautoterraformccsa01" -ForegroundColor Gray
    Write-Host "   Container: tfstate" -ForegroundColor Gray
    Write-Host "   Key: $Environment.tfstate" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "=" -NoNewline -ForegroundColor Red
    Write-Host ("=" * 79) -ForegroundColor Red
    Write-Host "ERROR: Terraform $Action failed for $Environment environment" -ForegroundColor Red
    Write-Host "=" -NoNewline -ForegroundColor Red
    Write-Host ("=" * 79) -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the error messages above for details" -ForegroundColor Yellow
    Write-Host "Refer to TROUBLESHOOTING.md for common issues and solutions" -ForegroundColor Yellow
    exit $LASTEXITCODE
} 