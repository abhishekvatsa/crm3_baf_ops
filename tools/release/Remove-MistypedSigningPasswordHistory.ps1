#requires -Version 5.1
<#
.SYNOPSIS
Local masked dialog to remove exact password lines mistakenly entered as
commands from the default PSReadLine history. Does not transmit anything.
.DESCRIPTION
Close the affected shell first. This touches only exact matching lines in its
default history file, not transcripts, security logs or other command lines.
No secret or history content is emitted, persisted in a backup, or logged.
#>
[CmdletBinding()]
param(
  [string]$HistoryPath = (Join-Path $env:APPDATA 'Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object Windows.Forms.Form
$form.Text = 'CRM3 - local password history cleanup'
$form.Size = New-Object Drawing.Size(650,350)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object Windows.Forms.Label
$label.Location = New-Object Drawing.Point(20,20)
$label.Size = New-Object Drawing.Size(600,76)
$label.Text = "Close the PowerShell window where you accidentally typed the password first.`r`nEnter that same password ONLY in the masked box below.`r`nThis removes exact matching saved-history lines locally. It does not export a key or send anything to Google."
$inputBox = New-Object Windows.Forms.TextBox
$inputBox.Location = New-Object Drawing.Point(20,105)
$inputBox.Size = New-Object Drawing.Size(595,25)
$inputBox.UseSystemPasswordChar = $true
$closedCheck = New-Object Windows.Forms.CheckBox
$closedCheck.Location = New-Object Drawing.Point(20,145)
$closedCheck.Size = New-Object Drawing.Size(595,25)
$closedCheck.Text = 'I closed the affected PowerShell window.'
$removeButton = New-Object Windows.Forms.Button
$removeButton.Location = New-Object Drawing.Point(20,184)
$removeButton.Size = New-Object Drawing.Size(285,34)
$removeButton.Text = 'Remove exact matching history lines'
$status = New-Object Windows.Forms.Label
$status.Location = New-Object Drawing.Point(20,236)
$status.Size = New-Object Drawing.Size(595,60)
$status.Text = 'No cleanup has been performed.'
$removeButton.Add_Click({
  if (-not $closedCheck.Checked) { $status.Text = 'Close the affected shell first, then check the box.'; return }
  if ($inputBox.Text.Length -eq 0) { $status.Text = 'The masked field is empty; nothing changed.'; return }
  $secretText = $inputBox.Text
  try {
    if (-not [IO.File]::Exists($HistoryPath)) {
      $status.Text = 'Default history file not found. Nothing changed; tell the signing task.'
      return
    }
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    $beforeBytes = [IO.File]::ReadAllBytes($HistoryPath)
    $bomLength = 0
    if ($beforeBytes.Length -ge 3 -and $beforeBytes[0] -eq 239 -and $beforeBytes[1] -eq 187 -and $beforeBytes[2] -eq 191) { $bomLength = 3 }
    $beforeText = $encoding.GetString($beforeBytes, $bomLength, $beforeBytes.Length - $bomLength)
    $kept = New-Object Text.StringBuilder
    $removed = 0
    $continuation = $false
    foreach ($line in [regex]::Split($beforeText, '(?<=\n)')) {
      $lineText = $line.TrimEnd([char[]]"`r`n")
      $continues = $lineText.EndsWith([string][char]96)
      if (-not $continuation -and -not $continues -and $lineText.Equals($secretText, [StringComparison]::Ordinal)) { $removed++ }
      else { [void]$kept.Append($line) }
      $continuation = $continues
    }
    if ($removed -eq 0) {
      $status.Text = 'No exact matching line found. Nothing changed; do not assume all traces are removed.'
      return
    }
    # Exclusive lock prevents rewriting a history file that changed since read.
    $file = [IO.File]::Open($HistoryPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Delete)
    $preparedPath = $null
    try {
      $currentBytes = New-Object byte[] $file.Length
      $read = 0
      while ($read -lt $currentBytes.Length) {
        $count = $file.Read($currentBytes, $read, $currentBytes.Length - $read)
        if ($count -eq 0) { throw 'Concurrent history change.' }
        $read += $count
      }
      if ([Convert]::ToBase64String($currentBytes) -cne [Convert]::ToBase64String($beforeBytes)) { throw 'Concurrent history change.' }
      $preparedPath = Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($HistoryPath))) ('crm3-history-cleaned-' + [Guid]::NewGuid().ToString('N') + '.tmp')
      $newBody = $encoding.GetBytes($kept.ToString())
      $prepared = [IO.File]::Open($preparedPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
      try {
        if ($bomLength -eq 3) { $prepared.Write($beforeBytes, 0, 3) }
        $prepared.Write($newBody, 0, $newBody.Length)
        $prepared.Flush($true)
      } finally { $prepared.Dispose() }
      [IO.File]::Replace($preparedPath, $HistoryPath, [NullString]::Value)
    } finally {
      $file.Dispose()
      if ($null -ne $preparedPath -and [IO.File]::Exists($preparedPath)) { [IO.File]::Delete($preparedPath) }
    }
    $status.Text = "Removed $removed exact matching line(s). Other history lines were retained. This does not check transcripts or security logs."
  } catch {
    $status.Text = 'Cleanup could not finish safely. No error content is shown to avoid exposing the password. Tell the signing task.'
  } finally {
    $inputBox.Clear()
    $secretText = $null
    $beforeText = $null
    $beforeBytes = $null
    $currentBytes = $null
  }
})
$form.Controls.AddRange(@($label,$inputBox,$closedCheck,$removeButton,$status))
$form.Add_Shown({ $inputBox.Focus() })
[void]$form.ShowDialog()
$form.Dispose()
