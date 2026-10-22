using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace Meteor.Tools.PatchTool;

// Signs certificates with sha1WithRSAEncryption, like the retail patch certificate. .NET's own
// RSA generator refuses SHA-1 for certificates.
sealed class Sha1RsaSignatureGenerator : X509SignatureGenerator
{
    // AlgorithmIdentifier { sha1WithRSAEncryption (1.2.840.113549.1.1.5), NULL }
    static readonly byte[] Sha1WithRsa = Convert.FromHexString("300D06092A864886F70D0101050500");

    readonly RSA key;

    public Sha1RsaSignatureGenerator(RSA key)
    {
        this.key = key;
    }

    public override byte[] GetSignatureAlgorithmIdentifier(HashAlgorithmName hashAlgorithm)
    {
        return (byte[])Sha1WithRsa.Clone();
    }

    public override byte[] SignData(byte[] data, HashAlgorithmName hashAlgorithm)
    {
        return key.SignData(data, HashAlgorithmName.SHA1, RSASignaturePadding.Pkcs1);
    }

    protected override PublicKey BuildPublicKey()
    {
        return CreateForRSA(key, RSASignaturePadding.Pkcs1).PublicKey;
    }
}
