import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Base64;
import java.util.zip.ZipFile;

/** Run only with a disposable synthetic PKCS12 fixture; never a production key. */
public final class PlaySigningPasswordDialogTest {
    private static final String FIXTURE_PASSWORD = "Fixture test #2026!";
    public static void main(String[] args) throws Exception {
        Path directory = Path.of(args[0]);
        Path store = directory.resolve("fixture.p12");
        KeyStore fixture = KeyStore.getInstance("PKCS12");
        try (var input = Files.newInputStream(store)) { fixture.load(input, FIXTURE_PASSWORD.toCharArray()); }
        KeyPairGenerator rsa = KeyPairGenerator.getInstance("RSA");
        rsa.initialize(2048);
        byte[] publicKey = rsa.generateKeyPair().getPublic().getEncoded();
        Path encryptionKey = directory.resolve("fixture-encryption-public.pem");
        Files.writeString(encryptionKey, "-----BEGIN PUBLIC KEY-----\n" +
            Base64.getMimeEncoder(64, new byte[]{10}).encodeToString(publicKey) +
            "\n-----END PUBLIC KEY-----\n", StandardCharsets.US_ASCII);
        Path output = directory.resolve("fixture-export.zip");
        char[] storePassword = FIXTURE_PASSWORD.toCharArray();
        char[] keyPassword = FIXTURE_PASSWORD.toCharArray();
        PlaySigningPasswordDialog.exportWithPasswords(store, "fixture", output, encryptionKey, storePassword, keyPassword);
        assertWiped(storePassword); assertWiped(keyPassword);
        verifyZip(output, fixture);

        byte[] before = Files.readAllBytes(output);
        expectFailure(store, output, encryptionKey, FIXTURE_PASSWORD, FIXTURE_PASSWORD);
        if (!Arrays.equals(before, Files.readAllBytes(output))) throw new AssertionError("Existing output overwritten");
        Path wrong = directory.resolve("wrong-password.zip");
        expectFailure(store, wrong, encryptionKey, "wrong-fixture-password", FIXTURE_PASSWORD);
        if (Files.exists(wrong)) throw new AssertionError("Wrong password produced output");

        // JKS permits distinct store/key passwords and verifies Unicode is not trimmed or reencoded.
        String unicodeStore = " fixture \u03A9 store ! ";
        String unicodeKey = " separate \u0939 key =! ";
        KeyStore separate = KeyStore.getInstance("JKS");
        separate.load(null, null);
        separate.setKeyEntry("fixture", fixture.getKey("fixture", FIXTURE_PASSWORD.toCharArray()),
            unicodeKey.toCharArray(), fixture.getCertificateChain("fixture"));
        Path separatePath = directory.resolve("separate-fixture.jks");
        try (var stream = Files.newOutputStream(separatePath)) { separate.store(stream, unicodeStore.toCharArray()); }
        char[] unicodeStoreChars = unicodeStore.toCharArray();
        char[] unicodeKeyChars = unicodeKey.toCharArray();
        Path separateOutput = directory.resolve("separate-export.zip");
        PlaySigningPasswordDialog.exportWithPasswords(separatePath, "fixture", separateOutput,
            encryptionKey, unicodeStoreChars, unicodeKeyChars);
        assertWiped(unicodeStoreChars); assertWiped(unicodeKeyChars);
        verifyZip(separateOutput, fixture);
        expectFailure(separatePath, directory.resolve("wrong-key.zip"), encryptionKey, unicodeStore, "wrong-fixture-key");
        System.out.println("PASS: PKCS12 export/certificate, wrong store/key rejection, output preservation, distinct Unicode passwords and buffer cleanup.");
    }
    private static void expectFailure(Path store, Path output, Path encryptionKey, String storeText, String keyText) throws Exception {
        char[] first = storeText.toCharArray(); char[] second = keyText.toCharArray();
        boolean failed = false;
        try { PlaySigningPasswordDialog.exportWithPasswords(store, "fixture", output, encryptionKey, first, second); }
        catch (Exception expected) { failed = true; }
        if (!failed) throw new AssertionError("Expected rejection");
        assertWiped(first); assertWiped(second);
    }
    private static void assertWiped(char[] value) {
        for (char item : value) if (item != '\0') throw new AssertionError("Password buffer not cleared");
    }
    private static void verifyZip(Path output, KeyStore fixture) throws Exception {
        try (ZipFile zip = new ZipFile(output.toFile())) {
            if (zip.getEntry("encryptedPrivateKey") == null || zip.getEntry("encryptedPrivateKey").getSize() == 0)
                throw new AssertionError("Encrypted entry missing");
            String pem = new String(zip.getInputStream(zip.getEntry("certificate.pem")).readAllBytes(), StandardCharsets.US_ASCII);
            byte[] certificate = Base64.getMimeDecoder().decode(pem.replace("-----BEGIN CERTIFICATE-----", "").replace("-----END CERTIFICATE-----", ""));
            MessageDigest hash = MessageDigest.getInstance("SHA-256");
            if (!Arrays.equals(hash.digest(certificate), hash.digest(fixture.getCertificate("fixture").getEncoded())))
                throw new AssertionError("Exported certificate mismatch");
        }
    }
}
