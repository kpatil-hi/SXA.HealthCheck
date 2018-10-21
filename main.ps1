Import-Function Get-CurrentSxaVersion

Class ValidationStep {
    [String]$Title
    [String]$Description
    [System.Object]$Script
    [System.Object]$Version
    [ValidationResult]$ValidationResult
}

enum Result {
    OK;
    Error;
    Warning
}

class ValidationResult {
    [Result]$Result
    [System.String]$Message
}

function Test-ValidVersion {
    param (
        [ValidationStep]$Step
    )
    $current = Get-CurrentSxaVersion
    $from = $Step.Version.From
    $to = $Step.Version.To
    $from -le $current -and ($to -eq "*" -or $to -ge $current)
}

function Test-BrokenLink {
    param (
        [Item]$Item,
        [ID]$FieldID
    )
    [ValidationResult]$result = New-Object ValidationResult
    $result.Result = [Result]::OK
    [Sitecore.Data.Fields.ReferenceField]$field = $Item.Fields[$FieldID]
    if ($field.Value -ne $null -and $field.TargetItem -eq $null) {
        $result.Message = "Could not find an item with id: $($field.Value)"
        $result.Result = [Result]::Error
    }
    return $result
}

function New-ResultObject {
    param ()

    [ValidationResult]$result = New-Object ValidationResult
    $result.Result = [Result]::OK
    $result.Message = ""
    $result
}

$steps =
@{
    Title       = "Field 'SiteMediaLibrary'";
    Description = "Checks whether 'SiteMediaLibrary' field contains proper reference to a site specific media library item";
    Version     = @{
        From = 1400;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        [ID]$id = [Sitecore.XA.Foundation.Multisite.Templates+Site+Fields]::SiteMediaLibrary

        $temp = Test-BrokenLink $SiteItem $id
        if ($temp.Result -eq [Result]::Error) {
            return $temp
        }

        [ValidationResult]$result = New-ResultObject
        return $result
    }
},
@{
    Title       = "Field 'ThemesFolder'";
    Description = "Checks whether 'ThemesFolder' field contains proper reference to a site specific themes folder item";
    Version     = @{
        From = 1400;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        [ID]$id = [Sitecore.XA.Foundation.Multisite.Templates+Site+Fields]::ThemesFolder

        $temp = Test-BrokenLink $SiteItem $id
        if ($temp.Result -eq [Result]::Error) {
            return $temp
        }

        [ValidationResult]$result = New-ResultObject
        return $result
    }
},
@{
    Title       = "Field 'AdditionalChildren'";
    Description = "Checks whether 'AdditionalChildren' field contains proper reference to a tenant shared media library folder and there are no broken links";
    Version     = @{
        From = 1000;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        Import-Function Get-SiteMediaItem
        [ValidationResult]$result = New-ResultObject
        [ID]$id = [Sitecore.XA.Foundation.Multisite.Templates+Media+Fields]::AdditionalChildren

        $siteMediaItem = Get-SiteMediaItem $SiteItem
        [Sitecore.Data.Fields.MultilistField]$field = $siteMediaItem.Fields[$id]
        $items = $field.GetItems()
        if ($items.Count -ne $field.TargetIDs.Count) {
            $result.Result = [Result]::Error
            $missingIDs = $field.TargetIDs | ? { $items.ID.Contains($_) -eq $false }
            $result.Message = "Could not find items with id: $($missingIDs -join ',')"
            return $result
        }
        return $result
    }
},
@{
    Title       = "Field 'Styles Optimizing Enabled'";
    Description = "Checks 'Styles Optimizing Enabled' field to determine if styles optimization is disabled";
    Version     = @{
        From = 1000;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        Import-Function Get-PageDesignsItem
        [ValidationResult]$result = New-ResultObject
        [ID]$id = [Sitecore.XA.Foundation.Theming.Templates+_Optimizable+Fields]::StylesOptimisingEnabled

        [Item]$pageDesignItem = Get-PageDesignsItem $SiteItem
        $fieldValue = $pageDesignItem.Fields[$id].Value

        $state = [Sitecore.MainUtil]::GetTristate($fieldValue, [Sitecore.Tristate]::Undefined)
        if ($state -eq [Sitecore.Tristate]::False) {
            $result.Result = [Result]::Warning
            $result.Message = "Styles optimization for yor site is explicitly disabled. This may cause performance problems. </br>You should enable assests optimization on production"
            return $result
        }
        return $result
    }
},
@{
    Title       = "Field 'Scripts Optimizing Enabled'";
    Description = "Checks 'Scripts Optimizing Enabled' field to determine if scripts optimization is disabled";
    Version     = @{
        From = 1000;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        Import-Function Get-PageDesignsItem
        [ValidationResult]$result = New-ResultObject
        [ID]$id = [Sitecore.XA.Foundation.Theming.Templates+_Optimizable+Fields]::ScriptsOptimisingEnabled

        [Item]$pageDesignItem = Get-PageDesignsItem $SiteItem
        $fieldValue = $pageDesignItem.Fields[$id].Value

        $state = [Sitecore.MainUtil]::GetTristate($fieldValue, [Sitecore.Tristate]::Undefined)
        if ($state -eq [Sitecore.Tristate]::False) {
            $result.Result = [Result]::Warning
            $result.Message = "Scripts optimization for yor site is explicitly disabled. This may cause performance problems. </br>You should enable assests optimization on production"
            return $result
        }
        return $result
    }
},
@{
    Title       = "Theme for Default device";
    Description = "Checks whether any theme is assigned to a default device";
    Version     = @{
        From = 1000;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        [ValidationResult]$result = New-ResultObject

        [ID]$defaultDeviceID = "{FE5D7FDF-89C0-4D99-9AA3-B5FBD009C9F3}"
        $deviceItem = Get-Item master: -ID $defaultDeviceID
        $theme = [Sitecore.XA.Foundation.Theming.ThemingContext]::new().GetThemeItem($siteItem, $deviceItem)

        if ($theme -eq $null) {
            $result.Result = [Result]::Error
            $result.Message = "There is no theme assigned to the Default device"
            return $result
        }
        return $result
    }
},
@{
    Title       = "Theme and Compatible Themes field consistency";
    Description = "Checks whether themes used in Theme-to-Device mapping are compatible with current site";
    Version     = @{
        From = 1000;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        Import-Function Get-PageDesignsItem
        Import-Function Get-SettingsItem
        [ValidationResult]$result = New-ResultObject
        [ID]$themesMappingFieldID = [Sitecore.XA.Foundation.Theming.Templates+SiteTheme+Fields]::Theme
        [ID]$compatibleThemesFieldIdD = [Sitecore.XA.Foundation.Theming.Templates+_Compatiblethemes+Fields]::Themes

        [Item]$pageDesignItem = Get-PageDesignsItem $SiteItem
        [Item]$settingsItem = Get-SettingsItem $SiteItem

        [Sitecore.XA.Foundation.SitecoreExtensions.CustomFields.MappingField]$themesMappingFields = $pageDesignItem.Fields[$themesMappingFieldID]
        [Sitecore.Data.Fields.MultilistField]$compatibleThemesField = $settingsItem.Fields[$compatibleThemesFieldIdD]
        $incorrectDeviceMapping = $themesMappingFields.Keys | % { $_.ToString() } | ? {
            $key = $_
            $theme = $themesMappingFields.Lookup($key)
            $compatibleThemesField.Items.Contains($theme.ID.ToString()) -eq $false
        }

        if ($incorrectDeviceMapping.Count -gt 0) {
            $result.Result = [Result]::Error
            $result.Message = "Some themes used for mapping are not compatible with current site. Please check themes mapping for following devices: $($incorrectDeviceMapping -join ',')"
            return $result
        }
        return $result
    }
},
@{
    Title       = "Site definitions conflicts";
    Description = "Checks whether current site definitions have any conflicts with other sites";
    Version     = @{
        From = 1500;
        To   = "*";
    };
    Script      = {
        param(
            [Item]$SiteItem
        )
        Import-Function Get-SettingsItem
        Import-Function Get-SxaSiteDefinitions

        [Item]$settingsItem = Get-SettingsItem $SiteItem
        $siteDefinitions = $settingsItem.Axes.GetDescendants() | ? { $_.TemplateID -eq "{EDA823FC-BC7E-4EF6-B498-CD09EC6FDAEF}" } | Wrap-Item | % { $_."SiteName" }

        $sites = Get-SxaSiteDefinitions | ? { $siteDefinitions.Contains($_.Name) } | ? { $_.State -eq "Conflict" }

        if ($sites.Count -gt 0) {
            $result.Result = [Result]::Error
            $result.Message = $sites[0].Conflict
            return $result
        }
        return $result
    }
}

$siteItem = Get-Item .
[Sitecore.Data.ID]$siteTemplateID = [Sitecore.XA.Foundation.Multisite.Templates+Site]::ID
if([Sitecore.Data.Managers.TemplateManager]::GetTemplate($siteItem).InheritsFrom($siteTemplateID) -eq $false){
    return
}

Write-Host "Validating site: $($siteItem.Paths.Path)" -ForegroundColor Cyan

# Icon mapping
$modeMapping = @{}
$modeMapping[[Result]::Warning] = "\Images\warning.png"
$modeMapping[[Result]::Error] = "\Images\error.png"
$modeMapping[[Result]::OK] = "\Images\check.png"

$steps | ? { Test-ValidVersion $_ } | % {
    [ValidationStep]$step = $_
    Write-Host "`nValidation step: $($step.Title)" -ForegroundColor Cyan

    [ValidationResult]$result = Invoke-Command -Script $step.Script -Args $siteItem
    $step.ValidationResult = $result
    if ($result.Result -eq [Result]::Error) {
        Write-Host $result.Message -ForegroundColor Red
    }
    if ($result.Result -eq [Result]::Warning) {
        Write-Host $result.Message -ForegroundColor Yellow
    }
    if ($result.Result -eq [Result]::OK) {
        Write-Host $result.Message -ForegroundColor Green
    }
    $step

} | Show-ListView  `
    -PageSize 25 `
    -Property `
        @{Label = "Title"; Expression = { $_.Title } },
        @{Label = "Icon"; Expression = { $modeMapping[$_.ValidationResult.Result] } },
        @{Label = "Description"; Expression = { $_.Description } },
        @{Label = "Message"; Expression = { $_.ValidationResult.Message } }