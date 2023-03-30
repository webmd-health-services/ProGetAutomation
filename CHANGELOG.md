
# ProGetAutomation Changelog

# 1.1.0

## Added

* Parameter `Url` to function `New-ProGetSession`. This replaces the `Uri` parameter. We'll always use a URL to connect
to ProGet, since it's HTTP-based software.
* Property `Url` on the ProGet session object. This replaces the `Uri` property.
* Parameter `MaxRequestSize` to function `Set-ProGetAsset`. The `Set-ProGetAsset` function no uploads files in parts
to avoid surpassing web server max request content length restrictions. Set this parameter to a value lower than your
web server's maximum request content length. The default value is 30MB/28.6MiB (the IIS web server's default max
request content length).

## Changed

* `Set-ProGetAsset` function now uploads files of any size.

## Deprecated

* The `New-ProGetSession` function's `Uri` parameter is deprecated. Use the new `Url` parameter instead.
* The `Uri` property on the ProGet session object. Use the new `Url` property instead.
