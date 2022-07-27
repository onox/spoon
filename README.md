[![Build status](https://github.com/onox/spoon/actions/workflows/build.yaml/badge.svg)](https://github.com/onox/spoon/actions/workflows/build.yaml)
[![Alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/spoon.json)](https://alire.ada.dev/crates/spoon.html)
[![License](https://img.shields.io/github/license/onox/spoon.svg?color=blue)](https://github.com/onox/spoon/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/onox/spoon.svg)](https://github.com/onox/spoon/releases/latest)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.svg)](https://gitter.im/ada-lang/Lobby)

# Spoon

An Ada 2012 library for `posix_spawn()` to spawn processes without a `fork()`.

## Usage

The package `Spoon` provides the function `Spawn` which can either
return a `Result` or a `Process`.
Calling the function which returns a `Result` will spawn a process,
wait for it to exit, and return the exit result.
The exit result contains the exit status, signal that caused the
process to crash or terminate, or the error code if the process
could not be spawned.
The function which returns a `Process` does not wait and returns immediately.

An object of the type `Process` provides the function `Wait_For_Exit`, which
waits for the process to exit and then return a `Result`.
Additionally, a `Process` or its process group can be terminated with the
procedures `Terminate_Process` and `Terminate_Group`.

To capture the standard output and error, provide a pointer to an object
implementing the protected interface `Output_Capturer`.
The package `Spoon.Output` provides the protected type `Text_Capturer`, which
can return an unbounded string.

The parameter `Attributes` of the function `Spawn` can be used to reset
the effective user and group if the parent process is a setuid binary,
or to let the spawned process have its own process group
(so that `Terminate_Group` can be called).

```ada
with Ada.Text_IO;
with Spoon.Output;

procedure Example is
   use all type Spoon.Exit_State;
   use type Spoon.Exit_Status;

   Arg_1 : aliased Spoon.Argument := Spoon.To_Argument ("2");

   Result : constant Spoon.Result :=
     Spoon.Spawn ("/bin/sleep", (1 => Arg_1'Unchecked_Access));
begin
   Ada.Text_IO.Put (Result.State'Image & " ");

   case Result.State is
      when Exited =>
         if Result.Exit_Status = Spoon.Success then
            Ada.Text_IO.Put_Line ("OK");
         else
            Ada.Text_IO.Put_Line ("with status" & Result.Exit_Status'Image);
         end if;
      when Crashed | Terminated =>
         Ada.Text_IO.Put_Line ("with signal" & Result.Signal'Image);
      when Error =>
         Ada.Text_IO.Put_Line ("with error" & Result.Error_Code'Image);
   end case;

   declare
      Text : aliased Spoon.Output.Text_Capturer;

      Process : constant Spoon.Process :=
        Spoon.Spawn ("whoami", Output => Text'Access, Kind => Spoon.Name);

      use Spoon.Output;
   begin
      if Process.Wait_For_Exit.State = Exited then
         Ada.Text_IO.Put_Line ("OK: '" & (+Text.Get (Spoon.Standard_Output)) & "'");
      else
         Ada.Text_IO.Put_Line ("not OK");
      end if;
   end;
end Example;
```

## Dependencies

In order to build the library, you need to have:

 * An Ada 2012 compiler

 * [Alire][url-alire] package manager

## License

The Ada code is licensed under the [Apache License 2.0][url-apache].
The first line of each Ada file should contain an SPDX license identifier tag that
refers to this license:

    SPDX-License-Identifier: Apache-2.0

  [url-alire]: https://alire.ada.dev/
  [url-apache]: https://opensource.org/licenses/Apache-2.0
