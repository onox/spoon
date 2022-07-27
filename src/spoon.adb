--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2022 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with Interfaces.C;

with Spoon.API;
with Spoon.Pipes;

package body Spoon is

   use type API.Error_Code;

   function To_Argument (Value : String) return Argument is
     (Argument (Value & L1.NUL));

   function Wait_For_Exit (PID : API.Process_ID) return Result is
      Wait_Status, Exit_Status : Interfaces.C.int;

      use all type API.Exit_Condition;
   begin
      loop
         if API.Waitpid (PID, Wait_Status, 0) = -1 then
            return (State => Spoon.Error, Error_Code => 127);
         end if;

         case API.Waitpid_Status (Wait_Status, Exit_Status) is
            when Exited =>
               case Exit_Status is
                  when 127 =>
                     --  If child process fails to execute the command, it will exit
                     --  with value 127 according to the man page of posix_spawn(3)
                     return (State => Spoon.Error, Error_Code => 127);
                  when others =>
                     return
                       (State       => Exited,
                        Exit_Status => Spoon.Exit_Status (Exit_Status));
               end case;
            when Crashed =>
               return (State => Crashed, Signal => Positive (Exit_Status));
            when Terminated =>
               return (State => Terminated, Signal => Positive (Exit_Status));
            when Unknown =>
               null;
         end case;
      end loop;
   end Wait_For_Exit;

   function Spawn
     (Executable : String;
      Arguments  : Argument_Array   := (1 .. 0 => null);
      Attributes : Spoon.Attributes := (IDs => Inherit, Group => Inherit);
      Kind       : Program_Kind     := File_Path;
      Output     : access Output_Capturer'Class := null) return Process
   is
      PID   : API.Process_ID := 1;
      Error : API.Error_Code := 0;

      Actions : API.File_Actions_Type
        (1 .. API.SE.Storage_Offset (API.File_Actions_Type_Size));
      Attribs : API.Spawn_Attributes_Type
        (1 .. API.SE.Storage_Offset (API.Spawn_Attributes_Type_Size));

      Error_Actions : API.Error_Code;
      Error_Attribs : API.Error_Code;

      Arg_0 : aliased Argument := To_Argument (Executable);

      Args : API.Argument_C_Array (0 .. Arguments'Length + 1) :=
        (0 => Arg_0'Unchecked_Access, others => null);
   begin
      for Index in Arguments'Range loop
         Args (Index) := Arguments (Index);
      end loop;

      Error_Actions := API.File_Actions_Init (Actions);
      Error_Attribs := API.Attributes_Init (Attribs);

      if Attributes.Group /= Inherit then
         Error := API.Attributes_Set_Process_Group (Attribs,
           (case Attributes.Group is
              when Same_As_PID => 0,
              when Custom      => Interfaces.C.int (Attributes.Group_ID),
              when Inherit     => 0));  --  Cannot be reached
      end if;

      Error := API.Attributes_Set_Flags (Attribs,
        (Reset_IDs     => Attributes.IDs /= Inherit,
         Process_Group => Attributes.Group /= Inherit,
         others        => False));

      declare
         Stdin, Stdout, Stderr : constant Pipe := Spoon.Pipes.Create_Pipe;
         --  TODO Do not create pipes at all if Output = null
      begin
         if Output /= null then
            Error := API.File_Actions_Add_Dup2 (Actions, Stdin.Read, 0);
            Error := API.File_Actions_Add_Dup2 (Actions, Stdout.Write, 1);
            Error := API.File_Actions_Add_Dup2 (Actions, Stderr.Write, 2);
            --  Pipes are automatically closed in child because they are
            --  created with O_CLOEXEC flag by function Create_Pipe
         end if;

         case Kind is
            when File_Path =>
               Error := API.Spawn
                 (PID, Args (Args'First), Actions, Attribs, Args, API.Environment);
            when Name =>
               Error := API.Spawnp
                 (PID, Args (Args'First), Actions, Attribs, Args, API.Environment);
         end case;

         Spoon.Pipes.Close (Stdin.Read);
         Spoon.Pipes.Close (Stdout.Write);
         Spoon.Pipes.Close (Stderr.Write);

         if Error_Actions = 0 then
            Error_Actions := API.File_Actions_Destroy (Actions);
         end if;

         if Error_Attribs = 0 then
            Error_Attribs := API.Attributes_Destroy (Attribs);
         end if;

         return Result : Process (Capture_Output => Output /= null, Output => Output) do
            Result.Process_ID := Process_ID (PID);
            Result.Error_Code := Integer (Error);
            Result.Group_Kind := Attributes.Group;
            Result.Stdin      := Stdin;
            Result.Stdout     := Stdout;
            Result.Stderr     := Stderr;
         end return;
      end;
   end Spawn;

   function Spawn
     (Executable : String;
      Arguments  : Argument_Array   := (1 .. 0 => null);
      Attributes : Spoon.Attributes := (IDs => Inherit, Group => Inherit);
      Kind       : Program_Kind     := File_Path;
      Output     : access Output_Capturer'Class := null) return Result
   is
      Process : constant Spoon.Process :=
        Spawn (Executable, Arguments, Attributes, Kind, Output);
   begin
      return Process.Wait_For_Exit;
   end Spawn;

   ----------------------------------------------------------------------------

   function Wait_For_Exit (Object : Process) return Result is
   begin
      return Result : constant Spoon.Result :=
        (if Object.Error_Code = 0 then
           Wait_For_Exit (API.Process_ID (Object.Process_ID))
         else
           (State => Spoon.Error, Error_Code => Object.Error_Code))
      do
         Spoon.Pipes.Close (Object.Stdin.Write);
         Spoon.Pipes.Close (Object.Stdout.Read);
         Spoon.Pipes.Close (Object.Stderr.Read);

         --  TODO Wait for tasks to terminate if Object.Capture_Output is True
      end return;
   end Wait_For_Exit;

   procedure Terminate_Process (Object : Process) is
      Error : constant API.Error_Code :=
        API.Kill_Process (API.Process_ID (Object.Process_ID), API.Signal_Terminate);
   begin
      pragma Assert (Error = 0);
   end Terminate_Process;

   procedure Terminate_Group (Object : Process) is
      Error : constant API.Error_Code :=
        API.Kill_Group (API.Group_ID (Object.Process_ID), API.Signal_Terminate);
   begin
      pragma Assert (Error = 0);
   end Terminate_Group;

   ----------------------------------------------------------------------------

   task body Pipe_Processor is
   begin
      loop
         declare
            Value : constant Ada.Streams.Stream_Element_Array := Spoon.Pipes.Read
              (case Kind is
                 when Standard_Output => Process.Stdout,
                 when Standard_Error  => Process.Stderr);
         begin
            exit when Value'Length = 0;
            Process.Output.Write (Value, Kind);
         end;
      end loop;
   end Pipe_Processor;

end Spoon;
