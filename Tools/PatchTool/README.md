# PatchTool

Signing for retail patch downloads.

ffxivboot only downloads a patch torrent whose `X-Signature` checks out against the certificate in
its `BINARY` resource 111. That is Square Enix's certificate, and its private key is gone. This
tool makes our own key and certificate, signs the retail torrents with it, and writes a copy of
`ffxivboot.exe` that trusts our certificate instead. Only the certificate bytes and their size
change; no code is patched. The torrents themselves stay exactly as retail shipped them.

The signature: RSA PKCS#1 v1.5 with an MD5 DigestInfo over `MD5(SHA1(torrent file))`, sent as
URL-safe base64. `verify` against the retail boot accepts the one surviving retail signature
(`D2012.09.19.0001.torrent`), so the format is boot's exactly.

## Use

From the repository root (`pt` = `dotnet run --project Tools/PatchTool --`):

```
pt keygen --out <secrets dir>
pt sign --key <secrets dir>/patch_key.pem --torrents <dir with <repo id>/metainfo/*.torrent> --out signatures.json
pt patch-boot --exe "<install>/ffxivboot.exe" --cert <secrets dir>/patch_cert.der --out <copy>/ffxivboot.exe
pt verify --cert <copy>/ffxivboot.exe --torrents <dir> --signatures signatures.json
pt extract-cert --exe "<install>/ffxivboot.exe" --out retail_cert.der
```

`keygen` makes `patch_key.pem` (private), `patch_cert.der` and `patch_cert.pem`: X.509 v3,
RSA 1024, sha1WithRSA, like the retail certificate. 1024 bits keeps the certificate (464 bytes)
inside boot's 792-byte resource, so it is replaced in place.

## The key

- `patch_key.pem` signs everything players' boot will accept. Keep it off git and off shared
  drives; the server reads it to sign version-check replies.
- A new key means a new boot copy for every player. `keygen` refuses to overwrite an existing key.
- The patched boot's Authenticode signature no longer matches. Windows still runs it.
