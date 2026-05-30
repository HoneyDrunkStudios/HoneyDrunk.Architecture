Option Explicit

Dim args, fso, shell, scriptDir, runnerRoot, jobId, configPath, command
Set args = WScript.Arguments

If args.Count < 2 Then
  Fail "Error: missing required arguments. Usage: Run-JobHidden.vbs <jobId> <configPath>", 2
End If

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
runnerRoot = fso.GetParentFolderName(scriptDir)
jobId = args.Item(0)
configPath = args.Item(1)

If Not IsSafeJobId(jobId) Then
  Fail "Error: unsafe jobId argument.", 2
End If

If ContainsUnsafeCommandChars(configPath) Then
  Fail "Error: unsafe configPath argument.", 2
End If

command = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File " & Quote(runnerRoot & "\Invoke-GridAgentRunner.ps1") & _
  " -JobId " & Quote(jobId) & _
  " -ConfigPath " & Quote(configPath) & _
  " -Once"

WScript.Quit shell.Run(command, 0, True)

Function Quote(value)
  Quote = Chr(34) & value & Chr(34)
End Function

Function IsSafeJobId(value)
  Dim re
  Set re = CreateObject("VBScript.RegExp")
  re.Pattern = "^[A-Za-z0-9_.-]+$"
  IsSafeJobId = re.Test(value)
End Function

Function ContainsUnsafeCommandChars(value)
  ContainsUnsafeCommandChars = InStr(value, Chr(34)) > 0 Or _
    InStr(value, "&") > 0 Or _
    InStr(value, "|") > 0 Or _
    InStr(value, ">") > 0 Or _
    InStr(value, "<") > 0 Or _
    InStr(value, "^") > 0 Or _
    InStr(value, "$") > 0 Or _
    InStr(value, "`") > 0 Or _
    InStr(value, vbCr) > 0 Or _
    InStr(value, vbLf) > 0
End Function

Sub Fail(message, code)
  WScript.Echo message
  WScript.Quit code
End Sub
