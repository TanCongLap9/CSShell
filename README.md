# CSShell
The C# Shell made with PowerShell.

## About
C# Shell (or CSShell) is a PowerShell module that can execute C# code as a REPL, or execute in a file. You can also compile the file into an executable that be run without PowerShell.
* In a REPL (read - evaluate - print - loop), every single statement you inputted get executed immediately and the result will be returned to the output.

## How to install C# Shell
1. Download this repository as ZIP or clone using `git clone` command.
2. Execute the file `setup.bat`.
3. Follow the instruction.
4. Done!

## REPL Commands
```
/help
/print <something>: Prints the value or returned result, same as Console.WriteLine(<something>).
/main ["edit"]: Runs code as body in the Main function.
/run ["edit" | <file>]: Runs code as raw C# (i.e. with class declaration and Main function which must be written) using a new C# instance.
/compile ["edit" | <file>]: Compiles code into an EXE file (as ConsoleApplication) and runs it.
/exit OR Ctrl+C: Ight imma head out.
```
