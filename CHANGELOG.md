# Changelog

All notable changes to this project will be documented in this file.

## Release 0.3.1

**Features**
* Support for downloading content for packages created by SCCM Applications (you do need to retrieve the package ID yourself first)
* Switches to package content lookup logic to parsing the INI files in the PkgLib location
* Metadata about distribution points that is no longer needed, now gets cleaned out

## Release 0.3.0

**Features**
* Ability to download SCCM packages from SCCM distribution points over HTTPS with TLS client authentication

## Release 0.2.0

**Features**
* Ability to download SCCM packages from SCCM distribution points over HTTP with Windows authentication
* Manage settings for distribution points separately from packages
* Documentation and usage guidance

## Release 0.1.0

**Features**
* Ability to download SCCM packages from SCCM distribution points over HTTP (anonymously)
