[![Build status](https://github.com/onox/spoon/actions/workflows/build.yaml/badge.svg)](https://github.com/onox/spoon/actions/workflows/build.yaml)
[![Alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/spoon.json)](https://alire.ada.dev/crates/spoon.html)
[![License](https://img.shields.io/github/license/onox/spoon.svg?color=blue)](https://github.com/onox/spoon/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/onox/spoon.svg)](https://github.com/onox/spoon/releases/latest)
[![Gitter chat](https://badges.gitter.im/gitterHQ/gitter.svg)](https://gitter.im/ada-lang/Lobby)

# Spoon

An Ada 2012 library for `posix_spawn()` to spawn processes without a `fork()`.

## Usage

```ada
with Ada.Text_IO;
with Spoon;

procedure Example is
   use all type Spoon.Result_State;
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

   if Spoon.Spawn ("whoami", Kind => Spoon.Name).State = Exited then
      Ada.Text_IO.Put_Line ("OK");
   else
      Ada.Text_IO.Put_Line ("not OK");
   end if;
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
