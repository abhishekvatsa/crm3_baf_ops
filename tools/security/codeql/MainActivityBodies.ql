/**
 * Extraction evidence only. The companion verifier requires every named body.
 * Run against the finalized database from the traced Android debug build.
 */
import java

from Method method
where
  method.fromSource() and
  method.getFile().getRelativePath() =
    "android/app/src/main/kotlin/in/co/sail/bsl/crm3/bafops/MainActivity.kt" and
  method.hasQualifiedName(
    "in.co.sail.bsl.crm3.bafops", "MainActivity",
    ["configureFlutterEngine", "configureCriticalAlarmChannel", "configureNetworkAccessChannel"]
  ) and
  exists(method.getBody())
select
  method.getFile().getRelativePath() as source_path,
  method.getDeclaringType().getQualifiedName() as class_name,
  method.getName() as method_name,
  method.getBody().getLocation().getStartLine() as body_start_line,
  method.getBody().getLocation().getEndLine() as body_end_line
