using System;
using System.Security.Cryptography;

namespace Meteor.Web.Patching;

// The signature ffxivboot checks on every .torrent its version check offers (X-Signature):
// RSA PKCS#1 v1.5 with an MD5 DigestInfo, over MD5(SHA1(torrent file bytes)). Boot hashes the
// file with SHA-1, then verifies those 20 bytes with MD5-with-RSA against the certificate in its
// BINARY resource 111. Retail sent it as URL-safe base64 with padding.
public static class PatchSignature
{
    public static string Sign(RSA key, byte[] torrent)
    {
        byte[] signature = key.SignData(SHA1.HashData(torrent), HashAlgorithmName.MD5, RSASignaturePadding.Pkcs1);
        return Convert.ToBase64String(signature).Replace('+', '-').Replace('/', '_');
    }

    public static bool Verify(RSA publicKey, byte[] torrent, string signature)
    {
        byte[] raw;
        try
        {
            raw = Convert.FromBase64String(signature.Trim().Replace('-', '+').Replace('_', '/'));
        }
        catch (FormatException)
        {
            return false;
        }
        return publicKey.VerifyData(SHA1.HashData(torrent), raw, HashAlgorithmName.MD5, RSASignaturePadding.Pkcs1);
    }
}
