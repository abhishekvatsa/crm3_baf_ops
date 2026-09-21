/** App extraction errors must prevent a successful coverage proof. */
import java
import semmle.code.java.Diagnostics

from Diagnostic diagnostic, string source
where
  diagnostic.getSeverity() > 3 and
  (
    source = diagnostic.getLocation().getFile().getRelativePath() and
    source.matches("android/app/src/%")
    or
    not exists(diagnostic.getLocation().getFile()) and source = "<unlocated>"
  )
select source as source_path, diagnostic.getSeverity() as severity,
  (if exists(diagnostic.getTag()) then diagnostic.getTag() else "") as tag,
  (if exists(diagnostic.getMessage()) then diagnostic.getMessage() else "") as message,
  (if exists(diagnostic.getFullMessage()) then diagnostic.getFullMessage() else "") as full_message
