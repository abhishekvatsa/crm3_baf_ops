# R1.16 Firebase Combined-Authority Reconciliation

This integration correction changes no workflow/business behaviour. It replaces the superseded debug-only Firebase configuration with the Firebase-generated combined authority after `CRM3-FB-RESTORE-001-C1` and binds the successful restoration evidence.

Current combined configuration:

- raw SHA-256: `2980012127521E625271620CF6F97262C49B725AC3099898C4FF27DFD1E9481B`
- semantic SHA-256: `A9FEE3B4E0770F9643C3929F41FDF69FFA8D638A5BE55EF81B34B893C4258FE2`
- debug OAuth retained: `894346496105-hmk7941e55ph206e6nr6ifvvqqqf7ee6.apps.googleusercontent.com`
- production OAuth restored: `894346496105-oljmi6mm7o790ue6o7cgcs20cakanjkg.apps.googleusercontent.com`

BAF-REF-005 remains immutable historical authority. The new restoration receipt is additive. Full R1.16 Flutter, Rules, governed Functions-emulator, audit, codegen and APK gates must be rerun before commit. Merge and deployment remain prohibited.
