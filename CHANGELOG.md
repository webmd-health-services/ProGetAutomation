<!--markdownlint-disable MD024 no-duplicate-header-->
<!--markdownlint-disable MD012 no-multiple-blanks-->

# ProGetAutomation Changelog

## 2.0.1

> Released 31 Jan 2024

Fixed: `Get-ProGetAssetContent` returns a web request object instead of the actual content.


## 2.0.0

> Released 11 Apr 2023

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

Add `-Method Post` to usages of `Invoke-ProGetRestMethod` that don't have a `-Method` argument. The default value
changed to `Get` from `Post`.

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
* The default value of the `Invoke-ProGetRestMethod` function's `Method` parameter changed to `Get` from `Post`.

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

> Released 31 Mar 2023

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


## 1.0.0

> Released 26 Jun 2021

Added support for ProGet 5.3.32


## 0.10.2

> Released 3 Sep 2021

Update vendored Zip module dependency to version 0.3.2 (from 0.3.1).


## 0.10.1

> Released 18 Aug 2020

* Update vendored Zip module dependency to version 0.3.1 (from 0.3.0).
* Fixed: ProGet universal packages created by ProGetAutomation are not extractable on non-Windows platforms due to using
  "" as the directory separator character.


## 0.10.0

> Released 12 Feb 2020

Improved import speed by merging functions into the module's .psm1 file.


## 0.9.0

> Released 25 Jan 2019

* Added `-Quiet` switch to `Add-ProGetUniversalPackageFile` to suppress progress messages while adding files to the
  package.
* Fixed: `Add-ProGetUniversalPackageFile` fails when passed multiple paths directly, in a non-pipeline manner.


## 0.8.0

> Released 27 Dec 2018

* `Add-ProGetUniversalPackageFile` is now an order of magnitude faster, thanks to performance improvements to the
  underlying Zip module used to add files to a universal package.
* `Add-ProGetUniversalPackageFile` now preserves file last write/modified date/times.
* Fixed: `Add-ProGetUniversalPackageFile` function behaves improperly when part of a pipeline, causing a major
  performance problem.
* Fix issue #7: the `Test-ProGetFeed` function ignores the feed's type, i.e. it always returns true if there is any feed
  with a given name, regardless of its type.
* Renamed the `New-ProGetFeed` and `Test-ProGetFeed` function's `FeedName` and `FeedType` parameters to `Name` and
  `Type`.


## 0.7.0

> Released 18 Dec 2018

* Created `New-ProGetUniversalPackage` function to create a new upack file with a correctly formatted upack.json file.
* Created `Add-ProGetUniversalPackageFile` function for adding files a upack file.
* Created `Get-ProGetUniversalPackage` function to read packages from a ProGet universal feed.
* Created `Get-ProGetFeed` function that gets a list of feeds from ProGet.
* Created `Remove-ProGetFeed` function for removing ProGet feeds.
* Adding `WhatIf` support to `Invoke-ProGetRestMethod` and `Invoke-ProGetNativeApiMethod`. When using `-WhatIf` switch,
  only GET requests will actually be made.
* Created `Remove-ProGetUniversalPackage` function to remove packages from a universal feed.
