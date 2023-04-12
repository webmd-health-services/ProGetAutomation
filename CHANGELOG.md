<!--markdownlint-disable MD024 no-duplicate-header-->

# ProGetAutomation Changelog

## 2.0.0

> Released 2023-4-11

### Upgrade Instructions

Updated `Get-ProGetFeed`, `New-ProGetFeed`, `Test-ProGetFeed`, and `Remove-ProGetFeed` functions to use ProGet's
[Feed Management API](https://docs.inedo.com/docs/proget-reference-api-feed-management) instead of the native API.
Ensure that API keys/credentials used with those functions have appropriate access to manage feeds.

Update usages of objects returned by `Get-ProGetFeed` and `New-ProGetFeed`. Rename these properties:

* `Active_Indicator` ➔ `active`
* `AllowUnknownLicenses_Indicator` ➔ `allowUnknownLicenses`
* `Feed_Description` ➔ `description`
* `Feed_Name` ➔ `name`
* `FeedType_Name` ➔ `feedType`

Remove these properties:

* `AllowUnassessedVulnerabilities_Indicator`
* `Cache_Connectors_Indicator`
* `DropPath_Text`
* `Feed_Id`
* `FeedConfiguration_Xml`
* `FeedGroup_Id`
* `FeedPathOverride_Text`
* `FeedState_Number`
* `LastPackageUpdate_Date`
* `LastSync_Date`
* `PackageStoreConfiguration_Xml`
* `ReplicationConfiguration_Xml`

Replace usages of the `ID` parameter on the `Get-ProGetFeed` and `Remove-ProGetFeed` functions to use `Name` instead.
The `ID` parameter was removed from those functions.

Remove usages of the `Type` parameter on the `Test-ProGetFeed` function. A feed's type is no longer needed to determine
if a feed exists. All feed names, regardless of type, must now be unique.

Make sure `Delete` HTTP verbs are allowed to your instance of ProGet. The `Remove-ProGetFeed` function now uses that
verb when deleting a feed.

Add `-ErrorAction Ignore` to usages of `Get-ProGetFeed`. That function now writes an error if a feed does not exist.

### Added

* The `Publish-ProGetUniversalPackage` function can now authenticate using a ProGet API key.

### Changed

* The `Get-ProGetFeed` and `New-ProGetFeed` functions now use the Feed Management API. The objects returned have
different properties. Update usages.
* The `Invoke-ProGetRestMethod` and `Invoke-ProGetNativeApiMethod` now uses `[Uri]::EscapeDataString([String])` to URL
encode query string values (instead of `[Web.HttpUtility]::UrlEncode([String])`).
* The `Remove-ProGetFeed` and `Test-ProGetFeed` functions now use the Feed Management API instead of the native API.
* The `Remove-ProGetFeed` function now uses the HTTP `Delete` verb (instead of the `Post` verb) when making the HTTP
request to delete a feed.
* The `Get-ProGetFeed` function now writes an error if a feed does not exist.

### Removed

#### Functionality

* Removed `charset` directive from the `Content-Type` header value sent to ProGet because ProGet can't handle that
directive.
* The `New-ProGetFeed` function no longer checks if the session has an API key.
* The `Test-ProGetFeed` function no longer checks if the session has an API key.

#### Parameters

* `ID` on the `Get-ProGetFeed` and `Remove-ProGetFeed` functions. The Feed Management API doesn't supports feed IDs.
Pass the feed name to the `Name` parameter instead.
* `Type` on function `Test-ProGetFeed`. All feeds, regardless of type, must now have a unique name.

## 1.1.0

> Released 2023-3-31

### Added

* Parameter `Url` to function `New-ProGetSession`. This replaces the `Uri` parameter. We'll always use a URL to connect
to ProGet, since it's HTTP-based software.
* Property `Url` on the ProGet session object. This replaces the `Uri` property.
* Parameter `MaxRequestSize` to function `Set-ProGetAsset`. The `Set-ProGetAsset` function no uploads files in parts
to avoid surpassing web server max request content length restrictions. Set this parameter to a value lower than your
web server's maximum request content length. The default value is 30MB/28.6MiB (the IIS web server's default max
request content length).

### Changed

* `Set-ProGetAsset` function now uploads files of any size.

### Deprecated

* The `New-ProGetSession` function's `Uri` parameter is deprecated. Use the new `Url` parameter instead.
* The `Uri` property on the ProGet session object. Use the new `Url` property instead.
