Set objArgs = WScript.Arguments
If objArgs.Count < 1 Then
    WScript.Quit 1
End If

filePath = objArgs(0)
Dim i
For i = 1 To objArgs.Count - 1
    filePath = filePath & " " & objArgs(i)
Next

Set objFSO = CreateObject("Scripting.FileSystemObject")
scriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\VTCheck.ps1"

Set objShell = CreateObject("WScript.Shell")

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & psScript & """ """ & filePath & """"

objShell.Run cmd, 0, False
