@{
  Intro = @"
C# Shell
Type /help for a list of shell commands.
"@
  Help = @"
/print <something>: Prints the value or returned result, same as Console.WriteLine(<something>).
/main [edit]: Runs code as body in the Main function.
  Append "edit" to this command to edit the code in a temporary file before running it
/run [edit/<file>]: Runs code as raw C# (i.e. with class declaration and Main function which must be written) using a new C# instance.
  Append "edit" to this command to edit the code in a temporary file before running it
/compile [edit/<file>]: Compiles code into an EXE file (as ConsoleApplication) and runs it.
  Append "edit" to this command to edit the code in a temporary file before running it
/exit OR Ctrl+C: Ight imma head out.
"@
  FileNotFound = "The file '{0}' does not exist."
  UnknownCommand = "Undefined command: {0}."
  ReferenceNotFullySupported = "Assigning result from function call is not fully supported yet.`nConsider running it in /main or /run command for full support."
  Pause = "Press Enter key to run."
}