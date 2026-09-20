import com.google.wireless.android.vending.developer.signing.tools.extern.export.ExportEncryptedPrivateKeyTool;
import com.google.wireless.android.vending.developer.signing.tools.extern.export.KeystoreKey;
import org.bouncycastle.jce.provider.BouncyCastleProvider;

import java.awt.Component;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.Security;
import java.util.Arrays;
import java.util.Optional;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JCheckBox;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;

/** Local password UI for the pinned Google PEPK tool. No secret process arguments. */
public final class PlaySigningPasswordDialog {
    public static void main(String[] args) {
        if (args.length != 4) {
            System.err.println("Expected keystore, alias, output ZIP and encryption public-key paths only.");
            System.exit(2);
        }
        // Passwords must come only from the masked dialog, never a console fallback.
        System.setIn(InputStream.nullInputStream());
        char[][] passwords = new char[2][];
        int result = 1;
        try {
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            SwingUtilities.invokeAndWait(() -> collectPasswords(passwords));
            if (passwords[0] == null) {
                System.out.println("Cancelled. No signing key was exported.");
                result = 2;
            } else if (passwords[0].length == 0 || passwords[1].length == 0) {
                showMessage("A password box was empty. No export was attempted.");
                result = 2;
            } else {
                exportWithPasswords(Path.of(args[0]), args[1], Path.of(args[2]),
                    Path.of(args[3]), passwords[0], passwords[1]);
                System.out.println("Encrypted ZIP created. The launcher will now verify its signing certificate.");
                result = 0;
            }
        } catch (Exception ignored) {
            // Do not expose exceptions, argument arrays or credential-bearing diagnostics.
            try { showMessage("The export did not complete. Check the original keystore and key passwords. Nothing was uploaded."); }
            catch (Exception alsoIgnored) { }
            System.err.println("Local signing export failed. No upload was attempted.");
        } finally {
            for (char[] value : passwords) if (value != null) Arrays.fill(value, '\0');
        }
        System.exit(result);
    }

    private static void collectPasswords(char[][] result) {
        JPasswordField store = new JPasswordField(32);
        JPasswordField key = new JPasswordField(32);
        JCheckBox same = new JCheckBox("Use the same password for the key", true);
        key.setEnabled(false);
        same.addActionListener(event -> { key.setEnabled(!same.isSelected()); key.setText(""); });
        JPanel panel = new JPanel();
        panel.setLayout(new BoxLayout(panel, BoxLayout.Y_AXIS));
        panel.add(new JLabel("Paste with Ctrl+V into these MASKED boxes only."));
        panel.add(new JLabel("Local encryption only: no upload and no password is saved."));
        panel.add(Box.createVerticalStrut(14));
        panel.add(new JLabel("Original release-keystore password:"));
        panel.add(store);
        panel.add(Box.createVerticalStrut(10));
        panel.add(same);
        panel.add(new JLabel("Key password (only if different):"));
        panel.add(key);
        for (Component component : panel.getComponents())
            if (component instanceof javax.swing.JComponent item) item.setAlignmentX(Component.LEFT_ALIGNMENT);
        try {
            int selection = JOptionPane.showOptionDialog(null, panel,
                "CRM3 - paste signing passwords", JOptionPane.OK_CANCEL_OPTION,
                JOptionPane.PLAIN_MESSAGE, null, new Object[]{"Encrypt locally", "Cancel"}, "Encrypt locally");
            if (selection == JOptionPane.OK_OPTION) {
                result[0] = store.getPassword();
                result[1] = same.isSelected() ? Arrays.copyOf(result[0], result[0].length) : key.getPassword();
            }
        } finally {
            store.setText("");
            key.setText("");
        }
    }

    private static void showMessage(String message) throws Exception {
        SwingUtilities.invokeAndWait(() -> JOptionPane.showMessageDialog(null,
            message, "CRM3 signing export", JOptionPane.INFORMATION_MESSAGE));
    }

    static void exportWithPasswords(Path store, String alias, Path output,
            Path encryptionKey, char[] storePassword, char[] keyPassword) throws Exception {
        PrintStream originalOut = System.out;
        PrintStream originalErr = System.err;
        try (PrintStream silent = new PrintStream(OutputStream.nullOutputStream())) {
            System.setOut(silent);
            System.setErr(silent);
            if (Files.exists(output)) throw new IllegalArgumentException("Output already exists.");
            if (storePassword.length == 0 || keyPassword.length == 0)
                throw new IllegalArgumentException("Empty password.");
            Security.addProvider(new BouncyCastleProvider());
            KeystoreKey existing = new KeystoreKey(store, alias, storePassword, keyPassword);
            new ExportEncryptedPrivateKeyTool().run(true, encryptionKey.toString(),
                output.toString(), existing, Optional.empty(), true);
        } finally {
            System.setOut(originalOut);
            System.setErr(originalErr);
            Arrays.fill(storePassword, '\0');
            Arrays.fill(keyPassword, '\0');
        }
    }
}
