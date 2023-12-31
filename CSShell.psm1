Function CompilationError($Err) {
  Process {If ($_.Exception) {
    # The first line of the exception is the error message
    $Target = $_.TargetObject
    If ($Target) {
      # Newer PowerShell uses this thing as compilation error
      Try {$IsCompilerError = $Target -is [Microsoft.PowerShell.Commands.AddTypeCompilerError]}
      Catch {$IsCompilerError = $Target -is [System.CodeDom.Compiler.CompilerError]}
    }
    If ($Target -and $IsCompilerError) {
      Write-Debug "Compilation Error at line $($Target.Line) col $($Target.Column)"
      Write-Host "error $($Target.ErrorNumber): $($Target.ErrorText)" -Background "Black" -Foreground "Red"
      # Display source code and line on which the error occurs
      For (
        $Line = [Math]::Max($Target.Line - 2, 1);
        $Line -le [Math]::Min($Target.Line + 2, $ActualCode.Split("`n").Length);
        $Line++
      ) {
        # Line starts at 1, so we must subtract it by 1 to get the index
        Write-Host ("{0, 3} | {1}" -f $Line, $ActualCode.Split("`n")[$Line - 1]) -Background "Black" -Foreground "Red"
        If ($Line -eq $Target.Line) {
          Write-Host ("{0, 3}   {1}^" -f "", (" " * ($Target.Column - 1))) -Background "Black" -Foreground "Red"
        }
      }
    }
    Else {
      Write-Debug "Compilation Error"
      Write-Host "error: $($_.Exception.Message)" -Background "Black" -Foreground "Red"
    }
  }}
}
Function RuntimeError($Err) {
  $RtError = $Err.Exception.InnerException
  If (!$RtError) {Throw $Err}
    Write-Host @"
Unhandled Exception:
$($RtError.GetType().FullName): $($RtError.Message)
$($RtError.StackTrace)
"@ -Background "Black" -Foreground "Red"
}
Function InputCommand($Prompt = "C#> ", [Switch]$TextEditor) {
  $Parentheses = $Brackets = 0
  $Code = ""
  If ($TextEditor) {
    $RunCodeFile = "$Env:Temp\_csshell_code.cs"
    If (![System.IO.File]::Exists($RunCodeFile)) {ni $RunCodeFile -Type "File" -Value $RunCode}
    Try {code $RunCodeFile} Catch {notepad $RunCodeFile}
    Write-Host $Res.Pause -Foreground "Yellow"
    While ([Console]::ReadKey($True).Key -ne [ConsoleKey]::Enter) {}
    $RunCode = $Code = [System.IO.File]::ReadAllText($RunCodeFile, [System.Text.Encoding]::UTF8)
  }
  Else {
    Do {
      Write-Host $Prompt -NoNewLine
      $Line = Read-Host
      $Code += $Line + "`n"
      ForEach ($Char In $Line.ToCharArray()) {
        Switch ($Char) {
          "(" {$Parentheses++}
          ")" {$Parentheses--}
          "{" {$Brackets++}
          "}" {$Brackets--}
        }
      }
      $Prompt = " " * $Prompt.Length
    } Until ($Parentheses -le 0 -and $Brackets -le 0)
  }
  $Code = $Code.TrimEnd("`n")
  Return $Code
}
Function UpdateRunParameters($Code = "") {
  $RunParameters.Code = -join ($Declarations.Variables | % {"$($_.Value)`n"}) + -join ($Declarations.Assignments | % {"$($_.Value)`n"}) + $Code
  $RunParameters.Usings = $Declarations.Usings -join "`n"
  $RunParameters.Functions = $Declarations.Functions -join "`n"
  $RunParameters.Classes = $Declarations.Classes -join "`n"
}
Function _RunCS([String]$Code, [String]$Usings, [String]$Functions, [String]$Classes, [Int]$Mode = 0, [String]$ToFile) {
  $Err = @()
  $ActualCode = ""
  $MainParams = -1
  <#
    .SYNOPSIS
    Runs CSharp Main function directly from code for testing, or define namespace or class (if $Code is empty)

    .PARAMETER Code
    The body of the Main function
    
    .PARAMETER Usings
    Namespaces to be using'd

    .PARAMETER Functions
    Functions inside the current class
    
    .PARAMETER Classes
    Classes inside the current namespace

    .PARAMETER Mode
    Runs code in an OOP way
    0: Code is the body of the Main function
    1: Code is the raw C# code, and will be wrapped in a instance namespace for running
    2: Code is compiled to an EXE file
  #>
  Function Indent($Code, $Spaces) {
    Return ($Code.Split("`n") | % {(" " * $Spaces) + $_}) -join "`n"
  }
  Try {
    # Compile
    Switch ($Mode) {
      0 {
        $NamespaceId = -Join $(1..32 | % {Get-Random -Input ([Char[]]([Char]"a"..[Char]"z" + [Char]"A"..[Char]"Z" + [Char]"0"..[Char]"9" + [Char]"_"))})
        $MainFunc = ""
        If ($Code) {
          $MainFunc = @"
public static void Main(string[] args) {
$(Indent $Code 2)
}
"@
        }
        $Types = @(Add-Type ($ActualCode = @"
$Usings
namespace _CSShellInstance$NamespaceId {
  public class Program {
$(Indent $MainFunc 4)
$(Indent $Functions 4)
  }
$(Indent $Classes 2)
}
"@) -Language "CSharp" -PassThru -ea "SilentlyContinue" -wa "SilentlyContinue" -ev Err -IgnoreWarnings)
      }
      1 {
        $SuitableMainMethods = @()
        $NamespaceId = -Join $(1..32 | % {Get-Random -Input ([Char[]]([Char]"a"..[Char]"z" + [Char]"A"..[Char]"Z" + [Char]"0"..[Char]"9" + [Char]"_"))})
        $Types = @(Add-Type ($ActualCode = "namespace _CSShellInstance$NamespaceId {$Code}") -Language "CSharp" -PassThru -ea "SilentlyContinue" -wa "SilentlyContinue" -ev Err -IgnoreWarnings)
        # Find Main function
        ForEach ($T In $Types) {
          $SuitableMainMethods += @($T.GetMethods([System.Reflection.BindingFlags]"NonPublic, Static") | ? {
            $_.Name -ceq "Main" -and @([Void], [Int]) -contains $_.ReturnType -and (
              $_.GetParameters().Count -eq 0 -or # Main()
              ($_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType -eq [String[]]) # Main(string[]) 
            )
          })
        }
        ForEach ($Method In $SuitableMainMethods) {
          $MainParams = $Method.GetParameters().Count
          $Exc = new Exception("Program has more than one entry point defined: ``$Method'")
          Write-Error -Exception $Exc -ea "SilentlyContinue" -ev +Err
        }
        If ($Err.Count -gt 1) {Throw new Exception}
        $Err = @()
        If ($MainParams -eq -1) {
          $Exc = new Exception("Program does not contain a static 'Main' method suitable for an entry point.")
          Write-Error -Exception $Exc -ea "SilentlyContinue" -ev Err
          Throw $Exc
        }
      }
      2 {Add-Type ($ActualCode = $Code) -Language "CSharp" -ea "SilentlyContinue" -wa "SilentlyContinue" -ev Err -OutputAs $ToFile -OutputType "ConsoleApplication" -IgnoreWarnings}
    }
    # Run Main
    Try {
      Switch ($Mode) {
        0 {If ($Code) {$Types[0]::Main(@())}}
        1 {
          $MainMethod = $SuitableMainMethods[0]
          If ($MainMethod.GetParameters().Count -eq 0) {
            $MainMethod.Invoke($Null, @())
          }
          ElseIf ($MainMethod.GetParameters().Count -eq 1) {
            $Params = [String[]]@()
            $MainMethod.Invoke($Null, (,$Params))
          }
        }
        2 {&$ToFile}
      }
    }
    Catch {
      RuntimeError $_
      If ($Mode -ne 2) {Return $False}
    }
    If ($Mode -ne 2) {Return $True}
  }
  Catch {
    If ($Err) {$Err | CompilationError}
    If ($Mode -ne 2) {Return $False}
  }
}
Function CSShell([System.Globalization.CultureInfo]$Language = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")) {
  <#
    .SYNOPSIS
    Runs CSharp Shell

    .PARAMETER Language
    Language of the CSharp Shell, defaulted to 'en-US'
  #>
  sal new New-Object
  $Res = @{}
  Try {Import-LocalizedData -Bind "Res" -UICulture $Language.TextInfo.CultureName -BaseDir "$PSScriptRoot\lang" -ea "Stop"}
  Catch {
    Import-LocalizedData -Bind "Res" -UICulture "en-US" -BaseDir "$PSScriptRoot\lang"
    Write-Warning "Cannot find the language '$Language', switching to the default language en-US"
  }
  $Declarations = @{
    Usings = new Collections.Generic.List[String] (,[String[]]("using System;"))
    Functions = new Collections.Generic.List[String]
    Classes = new Collections.Generic.List[String]
    Variables = new Collections.Generic.List[Hashtable]
    Assignments = new Collections.Generic.List[Hashtable]
  }
  $RunCode = ""
  $RunParameters = @{}
  UpdateRunParameters
  $Err = @()
  Write-Host $Res.Intro -Foreground "Yellow"
  While ($True) {
    $Code = InputCommand
    Switch -Regex ($Code) {
      "^\/help" {
        Write-Host $Res.Help -Foreground "Yellow"
        Break
      }
      "^\/print *(.*)" {
        Write-Debug "Print"
        UpdateRunParameters "System.Console.WriteLine($($Matches[1]));"
        _RunCS @RunParameters | Out-Null
        Break
      }
      "^\/main *(.*)" {
        Write-Debug "Main"
        if ($matches[1] -ceq "edit") {
          UpdateRunParameters (InputCommand -TextEditor)
        }
        Else {
          If (![System.IO.File]::Exists("$Env:Temp\_csshell_code.cs")) {
            InputCommand -TextEditor | Out-Null
          }
          UpdateRunParameters ([System.IO.File]::ReadAllText("$Env:Temp\_csshell_code.cs", [System.Text.Encoding]::UTF8))
        }
        _RunCS @RunParameters | Out-Null
        Break
      }
      "^\/run *(.*)" {
        Write-Debug "Run"
        $File = $Matches[1] -replace "`"(.*)`"", "`$1"
        If ($File -ceq "edit") {
          $Code = InputCommand -TextEditor
        }
        ElseIf ($File) {
          If (![System.IO.File]::Exists($File)) {
            Write-Host ($Res.FileNotFound -f $File) -Foreground "Yellow"
            Break
          }
          $Code = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
        }
        Else {
          If (![System.IO.File]::Exists("$Env:Temp\_csshell_code.cs")) {
            InputCommand -TextEditor | Out-Null
          }
          $Code = [System.IO.File]::ReadAllText("$Env:Temp\_csshell_code.cs", [System.Text.Encoding]::UTF8)
        }
        _RunCS $Code -Mode 1 | Out-Null
        Break
      }
      "^\/compile *(.*)" {
        Write-Debug "Compile"
        $File = $Matches[1] -replace "`"(.*)`"", "`$1"
        If ($File -ceq "edit") {
          $Code = InputCommand -TextEditor
          $SaveTo = "$Env:Temp\_csshell_code.exe"
        }
        ElseIf ($File) {
          If (![System.IO.File]::Exists($File)) {
            Write-Host ($Res.FileNotFound -f $File) -Foreground "Yellow"
            Break
          }
          $Code = [System.IO.File]::ReadAllText($File, [System.Text.Encoding]::UTF8)
          $SaveTo = "$File\..\$((gi $File).BaseName).exe"
        }
        Else {
          If (![System.IO.File]::Exists("$Env:Temp\_csshell_code.cs")) {
            InputCommand -TextEditor | Out-Null
          }
          $Code = [System.IO.File]::ReadAllText("$Env:Temp\_csshell_code.cs", [System.Text.Encoding]::UTF8)
          $SaveTo = "$Env:Temp\_csshell_code.exe"
        }
        _RunCS $Code -Mode 2 -ToFile $SaveTo
        Break
      }
      "^\/exit" {Return}
      "^\/" {Write-Host ($Res.UnknownCommand -f $Code) -Foreground "Yellow"}

      "^using" {
        If ($Code -ceq "using") { # As its own
          Write-Host $RunParameters.Usings
        }
        Else { # With a namespace
          Write-Debug "Using"
          $Declarations.Usings.Add($Code)
          UpdateRunParameters
          If (!(_RunCS @RunParameters)) {$Declarations.Usings.RemoveAt($Declarations.Usings.Count - 1); UpdateRunParameters}
        }
        Break
      }
      "class|struct|delegate|enum" { # Type definition
        Write-Debug "Type"
        If ($Code -notmatch "^public|^protected|^private") {$Code = $Code.Insert(0, "public ")}
        $Declarations.Classes.Add($Code)
        UpdateRunParameters
        If (!(_RunCS @RunParameters)) {$Declarations.Classes.RemoveAt($Declarations.Classes.Count - 1); UpdateRunParameters}
        Break
      }
      ".+ +[^ ]+ *\(.*\) *{.*}" { # Function definition
        Write-Debug "Function"
        If ($Code -notmatch "^public|^protected|^private") {$Code = $Code.Insert(0, "public static ")}
        $Declarations.Functions.Add($Code)
        UpdateRunParameters
        If (!(_RunCS @RunParameters)) {$Declarations.Functions.RemoveAt($Declarations.Functions.Count - 1); UpdateRunParameters}
        Break
      }
      "^([^ ]+) +(\w+) *= *(.+)" { # Variable definition
        Write-Debug "Definition"
        $Type, $Name, $Value = $Matches[1], $Matches[2], $Matches[3].TrimEnd(";")
        If ($Variable = $Declarations.Variables.Find({Param ($v) $v.Name -ceq $Name})) { # If variable is already declared, set its type and value
          $OldAssignments = $Declarations.Assignments
          $Assignments = new Collections.Generic.List[Hashtable](,$OldAssignments)
          $Assignments.RemoveAll({Param ($v) $v.Name -ceq $Name}) | Out-Null
          $OldValue = $Variable.Value
          $Variable.Value = $Code
          $Declarations.Assignments = $Assignments
          UpdateRunParameters
          If (!(_RunCS @RunParameters)) {$Variable.Value = $OldValue; $Declarations.Assignments = $OldAssignments; UpdateRunParameters; Break}
        }
        Else {
          $Declarations.Variables.Add(@{Name = $Name; Value = $Code})
          UpdateRunParameters
          If (!(_RunCS @RunParameters)) {$Declarations.Variables.RemoveAt($Declarations.Variables.Count - 1); UpdateRunParameters; Break}
        }
        If ($Value -match "\(.*\)") { # Object type or result from function call
          Write-Warning $Res.ReferenceNotFullySupported
        }
        Break
      }
      "^([^ ]+) +(\w+)$" { # Variable declaration
        Write-Debug "Declaration"
        $Type, $Name = $Matches[1], $Matches[2].TrimEnd(";")
        If ($Variable = $Declarations.Variables.Find({Param ($v) $v.Name -ceq $Name})) { # If variable is already declared, set its type and value
          $OldAssignments = $Declarations.Assignments
          $Assignments = new Collections.Generic.List[Hashtable](,$OldAssignments)
          $Assignments.RemoveAll({Param ($v) $v.Name -ceq $Name}) | Out-Null
          $OldValue = $Variable.Value
          $Variable.Value = $Code
          $Declarations.Assignments = $Assignments
          UpdateRunParameters
          If (!(_RunCS @RunParameters)) {$Variable.Value = $OldValue; $Declarations.Assignments = $OldAssignments; UpdateRunParameters; Break}
        }
        Else {
          $Declarations.Variables.Add(@{Name = $Name; Value = $Code})
          UpdateRunParameters
          If (!(_RunCS @RunParameters)) {$Declarations.Variables.RemoveAt($Declarations.Variables.Count - 1); UpdateRunParameters; Break}
        }
        Break
      }
      "^([^ ]+) *([^ ]{0,2}=) *(.*)" { # Variable assignment
        Write-Debug "Assignment"
        $Name, $Operator, $Value = $Matches[1], $Matches[2], $Matches[3].TrimEnd(";")
        $Declarations.Assignments.Add(@{Name = $Name; Value = $Code})
        UpdateRunParameters
        If (!(_RunCS @RunParameters)) {$Declarations.Assignments.RemoveAt($Declarations.Assignments.Count - 1); UpdateRunParameters; Break}
        If ($Value -match "\(.*\)") { # Object type or result from function call
          Write-Warning $Res.ReferenceNotFullySupported
        }
        Break
      }
      "^$" {Break} # No-op
      Default {
        Write-Debug "Run"
        UpdateRunParameters $Code
        _RunCS @RunParameters | Out-Null
      }
    }
  }
}
Function _Launcher() {
  Write-Host "[en] English";
  Write-Host "[vi] Tiếng Việt";
  $Lang = Read-Host -Prompt "Choose language";
  csh $Lang
}
sal cssh CSShell
sal csh CSShell
Export-ModuleMember -Function ("CSShell", "_Launcher") -Alias ("cssh", "csh")