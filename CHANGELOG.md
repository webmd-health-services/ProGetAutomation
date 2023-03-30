
# ProGetAutomation Changelog

# 1.1.0

## Added

* Parameter `Url` to function `New-ProGetSession`. This replaces the `Uri` parameter. We'll always use a URL to connect
to ProGet, since it's HTTP-based software.
* Property `Url` on the ProGet session object. This replaces the `Uri` property.

## Deprecated

* The `New-ProGetSession` function's `Uri` parameter is deprecated. Use the new `Url` parameter instead.
* The `Uri` property on the ProGet session object. Use the new `Url` property instead.
