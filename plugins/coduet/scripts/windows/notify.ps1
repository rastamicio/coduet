# Shows a Coduet notice window.  notify.ps1 -Message <text> [-TaskName <scheduled task to remove>]
param([string]$Message, [string]$TaskName = '')
if ($TaskName) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($Message, 'Coduet') | Out-Null
