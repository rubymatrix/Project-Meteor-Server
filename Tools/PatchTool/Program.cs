using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using Meteor.Tools.PatchTool;

// Commands:
//   keygen --out <dir>                                    patch_key.pem (private, keep secret) + patch_cert.der/.pem
//   sign --key <patch_key.pem> --torrents <dir> --out <signatures.json>
//                                                         signs every <repo id>/metainfo/D<version>.torrent under dir
//   verify --cert <cert.der|cert.pem|ffxivboot.exe> --torrents <dir> --signatures <signatures.json>
//   verify --cert <...> --torrent <file> --signature <base64>
//   extract-cert --exe <ffxivboot.exe> --out <cert.der>
//   patch-boot --exe <ffxivboot.exe> --cert <patch_cert.der> --out <ffxivboot copy>
//                                                         writes a copy of boot that trusts the certificate
string cmd = args.Length > 0 ? args[0] : "";
var opts = ParseOptions(args.Skip(1).ToArray());

try
{
    switch (cmd)
    {
        case "keygen":
        {
            string dir = Require(opts, "out");
            string keyPath = Path.Combine(dir, "patch_key.pem");
            if (File.Exists(keyPath))
                return Fail($"{keyPath} already exists; a new key would invalidate every signature and the patched boot");
            Directory.CreateDirectory(dir);

            // Same shape as the retail certificate: X.509 v3, RSA 1024, e=65537, sha1WithRSA.
            // 1024 bits keeps the certificate within boot's 792-byte resource.
            using RSA key = RSA.Create(1024);
            var signer = new Sha1RsaSignatureGenerator(key);
            var name = new X500DistinguishedName("CN=Project Meteor Patch Signing");
            var request = new CertificateRequest(name, signer.PublicKey, HashAlgorithmName.SHA1);
            using X509Certificate2 cert = request.Create(name, signer, DateTimeOffset.UtcNow.AddDays(-1),
                DateTimeOffset.UtcNow.AddYears(50), RandomNumberGenerator.GetBytes(8));

            File.WriteAllText(keyPath, key.ExportPkcs8PrivateKeyPem());
            File.WriteAllBytes(Path.Combine(dir, "patch_cert.der"), cert.RawData);
            File.WriteAllText(Path.Combine(dir, "patch_cert.pem"), cert.ExportCertificatePem());
            Console.WriteLine($"wrote {keyPath} (private: keep it off git) and patch_cert.der ({cert.RawData.Length} bytes)");
            return 0;
        }
        case "sign":
        {
            using RSA key = RSA.Create();
            key.ImportFromPem(File.ReadAllText(Require(opts, "key")));
            var signatures = new SortedDictionary<string, string>(StringComparer.Ordinal);
            foreach (var (id, path) in Torrents(Require(opts, "torrents")))
                signatures[id] = PatchSignature.Sign(key, File.ReadAllBytes(path));
            string outPath = Require(opts, "out");
            File.WriteAllText(outPath, JsonSerializer.Serialize(signatures, new JsonSerializerOptions { WriteIndented = true }) + "\n");
            Console.WriteLine($"signed {signatures.Count} torrents -> {outPath}");
            return 0;
        }
        case "verify":
        {
            using RSA publicKey = LoadPublicKey(Require(opts, "cert"));
            if (opts.TryGetValue("torrent", out string? single))
            {
                bool ok = PatchSignature.Verify(publicKey, File.ReadAllBytes(single), Require(opts, "signature"));
                Console.WriteLine(ok ? "valid" : "INVALID");
                return ok ? 0 : 1;
            }
            var signatures = JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(Require(opts, "signatures")))!;
            int valid = 0, invalid = 0, missing = 0;
            foreach (var (id, path) in Torrents(Require(opts, "torrents")))
            {
                if (!signatures.TryGetValue(id, out string? signature))
                {
                    missing++;
                    Console.WriteLine($"  no signature: {id}");
                }
                else if (PatchSignature.Verify(publicKey, File.ReadAllBytes(path), signature))
                {
                    valid++;
                }
                else
                {
                    invalid++;
                    Console.WriteLine($"  INVALID: {id}");
                }
            }
            Console.WriteLine($"{valid} valid, {invalid} invalid, {missing} without a signature");
            return invalid == 0 && missing == 0 ? 0 : 1;
        }
        case "extract-cert":
        {
            byte[] cert = BootCertificate.Read(File.ReadAllBytes(Require(opts, "exe")));
            File.WriteAllBytes(Require(opts, "out"), cert);
            using var parsed = X509CertificateLoader.LoadCertificate(cert);
            Console.WriteLine($"{cert.Length} bytes: {parsed.Subject}");
            return 0;
        }
        case "patch-boot":
        {
            string exePath = Path.GetFullPath(Require(opts, "exe"));
            string outPath = Path.GetFullPath(Require(opts, "out"));
            if (exePath == outPath)
                return Fail("--out must be a different file: the retail ffxivboot.exe stays as it is");
            byte[] cert = File.ReadAllBytes(Require(opts, "cert"));
            using (X509CertificateLoader.LoadCertificate(cert)) { }   // must be DER

            byte[] patched = BootCertificate.Replace(File.ReadAllBytes(exePath), cert);
            if (!BootCertificate.Read(patched).AsSpan().SequenceEqual(cert))
                return Fail("certificate didn't read back from the patched copy");
            File.WriteAllBytes(outPath, patched);
            Console.WriteLine($"wrote {outPath}: resource 111 now holds the {cert.Length}-byte certificate");
            return 0;
        }
        default:
            Console.Error.WriteLine("commands: keygen, sign, verify, extract-cert, patch-boot (see Program.cs)");
            return 2;
    }
}
catch (Exception e) when (e is IOException or InvalidDataException or InvalidOperationException or CryptographicException or ArgumentException)
{
    return Fail(e.Message);
}

static int Fail(string message)
{
    Console.Error.WriteLine(message);
    return 1;
}

static Dictionary<string, string> ParseOptions(string[] args)
{
    var opts = new Dictionary<string, string>();
    for (int i = 0; i + 1 < args.Length; i += 2)
    {
        if (!args[i].StartsWith("--"))
            throw new ArgumentException($"expected an --option, got {args[i]}");
        opts[args[i][2..]] = args[i + 1];
    }
    return opts;
}

static string Require(Dictionary<string, string> opts, string name)
{
    return opts.TryGetValue(name, out string? value) ? value : throw new ArgumentException($"missing --{name}");
}

// <dir>/<repo id>/metainfo/D<version>.torrent, keyed "<repo id>/D<version>".
static IEnumerable<(string Id, string Path)> Torrents(string dir)
{
    foreach (string path in Directory.GetFiles(dir, "*.torrent", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
    {
        string repo = Path.GetFileName(Path.GetDirectoryName(Path.GetDirectoryName(path))!);
        yield return ($"{repo}/{Path.GetFileNameWithoutExtension(path)}", path);
    }
}

// From a DER or PEM certificate, or from the certificate inside an ffxivboot.exe.
static RSA LoadPublicKey(string path)
{
    byte[] bytes = File.ReadAllBytes(path);
    byte[] der = bytes.Length > 1 && bytes[0] == 'M' && bytes[1] == 'Z' ? BootCertificate.Read(bytes) : bytes;
    using var cert = der[0] == 0x30 ? X509CertificateLoader.LoadCertificate(der) : X509Certificate2.CreateFromPem(File.ReadAllText(path));
    return cert.GetRSAPublicKey() ?? throw new InvalidDataException("certificate has no RSA key");
}
