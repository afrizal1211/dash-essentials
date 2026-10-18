# Release signing identity

`release-cert.sha256` holds the SHA-256 digest of the DER-encoded certificate that
must sign every release APK of this project. It is not a hash of the APK or of a
keystore; it is the fingerprint of the signing certificate itself, which is what
Android uses to decide whether an installed application may be updated in place.

The private key is not in this repository and must never be committed. Publish it
to CI as repository secrets:

| Secret | Value |
| --- | --- |
| `DASH_RELEASE_KEYSTORE_BASE64` | `base64 -w0 dash-essential-release.p12` |
| `DASH_RELEASE_KEY_PASS` | the keystore and key password |
| `DASH_RELEASE_KEY_ALIAS` | optional, defaults to `dash-essential` |

`.github/workflows/build-dash-essential-module.yml` decodes the keystore, signs
with it, and then verifies the resulting certificate against
`release-cert.sha256`. A wrong, stale, or missing key therefore fails the build
instead of silently producing something that only looks like a release. Without
the secrets the workflow falls back to a throwaway development key and emits a
`-dev` ZIP, which never writes the stable module path.

Every published version must reuse the same key. Android replaces an installed
application only when the signatures match, so a new key means users would have
to uninstall first and lose application-local preferences.

## Upstream Rodin Essential

This project is a port of Rodin Essential by NEESCHAL-3
(<https://github.com/NEESCHAL-3/Rodin-Essential>, Apache-2.0). That project's
release certificate fingerprint is preserved in `UPSTREAM_RELEASE_CERT.sha256`
for provenance. Its private key was never distributed and cannot be recovered,
so this port carries its own signing identity recorded in
`release-cert.sha256`; the two are not interchangeable, and a device holding an
upstream-signed application will refuse to update it with a port-signed build.

## Rotating the key

1. Generate a new PKCS#12 keystore and keep an offline backup of it.
2. Export the certificate and compute the digest:
   `keytool -exportcert -keystore release.p12 -storepass … -alias dash-essential -file cert.der`
   `sha256sum cert.der`
3. Replace `release-cert.sha256` with the new digest.
4. Update the `DASH_RELEASE_KEYSTORE_BASE64` and `DASH_RELEASE_KEY_PASS`
   secrets.
5. Document the change in `CHANGELOG.md`: every existing installation becomes
   uninstallable-from-update and must be removed before the new build installs.
