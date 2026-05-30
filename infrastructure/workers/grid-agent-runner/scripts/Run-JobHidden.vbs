Option Explicit

Dim args, fso, shell, scriptDir, runnerRoot, jobId, configPath, command
Set args = WScript.Arguments

If args.Count < 2 Then
  WScript.Quit 2
End If

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
runnerRoot = fso.GetParentFolderName(scriptDir)
jobId = args.Item(0)
configPath = args.Item(1)

command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File " & Quote(runnerRoot & "\Invoke-GridAgentRunner.ps1") & _
  " -JobId " & Quote(jobId) & _
  " -ConfigPath " & Quote(configPath) & _
  " -Once"

shell.Run command, 0, True

Function Quote(value)
  Quote = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
