/** App extraction errors must prevent a successful coverage proof. */
import java
import semmle.code.java.Diagnostics

string tagOrEmpty(Diagnostic diagnostic) {
  result = diagnostic.getTag()
  or
  not exists(diagnostic.getTag()) and result = ""
}

string messageOrEmpty(Diagnostic diagnostic) {
  result = diagnostic.getMessage()
  or
  not exists(diagnostic.getMessage()) and result = ""
}

string fullMessageOrEmpty(Diagnostic diagnostic) {
  result = diagnostic.getFullMessage()
  or
  not exists(diagnostic.getFullMessage()) and result = ""
}

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
  tagOrEmpty(diagnostic) as tag, messageOrEmpty(diagnostic) as message,
  fullMessageOrEmpty(diagnostic) as full_message
