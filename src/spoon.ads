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

private with Ada.Characters.Latin_1;

with Ada.Streams;

package Spoon is
   pragma Preelaborate;

   type Argument (<>) is limited private;

   function To_Argument (Value : String) return Argument
     with Pre => Value'Length > 0;

   type Argument_Access is access all Argument
     with Size => Standard'Address_Size;

   type Argument_Array is array (Positive range <>) of not null Argument_Access;

   ----------------------------------------------------------------------------

   type Exit_State is (Error, Exited, Crashed, Terminated);

   type Exit_Status is new Integer;

   Success : constant Exit_Status;

   type Result (State : Exit_State) is record
      case State is
         when Error =>
            Error_Code : Integer;
         when Exited =>
            Exit_Status : Spoon.Exit_Status;
         when Crashed | Terminated =>
            Signal : Positive;
      end case;
   end record;

   ----------------------------------------------------------------------------

   type Process (<>) is tagged limited private;

   function In_Own_Group (Object : Process) return Boolean;
   --  Return True if the process has its own process group, False otherwise
   --
   --  A process has its own group if function Spawn was called with
   --  Attributes.Group = Same_As_PID.

   function Wait_For_Exit (Object : Process) return Result;
   --  Block and wait for the process to terminate, either by
   --  exiting or crashing, and return the exit result
   --
   --  The exit result contains the exit status, signal that caused the
   --  process to crash or terminate, or the error code if the process
   --  could not be spawned.

   procedure Terminate_Process (Object : Process);
   --  Terminate the process

   procedure Terminate_Group   (Object : Process)
     with Pre => Object.In_Own_Group;
   --  Terminate the whole process group of the process
   --
   --  Only allowed if the group ID of the process is the same as its process ID.

   ----------------------------------------------------------------------------

   type Output_Capturer is protected interface;

   type Output_Kind is (Standard_Output, Standard_Error);

   procedure Write
     (Object : in out Output_Capturer;
      Value  : Ada.Streams.Stream_Element_Array;
      Kind   : Output_Kind) is abstract
   with Synchronization => By_Protected_Procedure;

   ----------------------------------------------------------------------------

   type Program_Kind is (File_Path, Name);

   type IDs_Kind is (Inherit, Real);
   --  Real will drop effective IDs if parent is a setuid binary

   type Process_Group_Kind is (Inherit, Same_As_PID, Custom);

   type Process_ID is range 1 .. Positive'Last;
   type Group_ID   is range 2 .. Positive'Last;
   --  2 or higher (see man killpg(3))

   type Attributes
     (IDs   : IDs_Kind;
      Group : Process_Group_Kind) is
   record
      case Group is
         when Custom => Group_ID : Spoon.Group_ID;
         when others => null;
      end case;
   end record;

   function Spawn
     (Executable : String;
      Arguments  : Argument_Array   := (1 .. 0 => null);
      Attributes : Spoon.Attributes := (IDs => Inherit, Group => Inherit);
      Kind       : Program_Kind     := File_Path;
      Output     : access Output_Capturer'Class := null) return Process
   with Pre => Executable'Length > 0;
   --  Spawn a process using the given executable, which is either a path
   --  to a file or the name of the program found using the PATH environment variable

   function Spawn
     (Executable : String;
      Arguments  : Argument_Array   := (1 .. 0 => null);
      Attributes : Spoon.Attributes := (IDs => Inherit, Group => Inherit);
      Kind       : Program_Kind     := File_Path;
      Output     : access Output_Capturer'Class := null) return Result
   with Pre => Executable'Length > 0;
   --  Spawn a process using the given executable, which is either a path
   --  to a file or the name of the program found using the PATH environment variable
   --
   --  Wait for the spawned process to exit and return the exit result.

private

   Success : constant Exit_Status := 0;

   package L1 renames Ada.Characters.Latin_1;

   type Argument is new String
     with Dynamic_Predicate => Argument (Argument'Last) = L1.NUL;

   type File_Descriptor is new Integer;

   type Pipe is tagged record
      Read, Write : File_Descriptor;
   end record;

   task type Pipe_Processor
     (Process : not null access Spoon.Process;
      Kind    : Output_Kind);

   type Process
     (Capture_Output : Boolean;
      Output         : access Output_Capturer'Class) is tagged limited
   record
      Process_ID : Spoon.Process_ID;
      Error_Code : Integer;
      Group_Kind : Process_Group_Kind;

      Stdin, Stdout, Stderr : Pipe;

      case Capture_Output is
         when True =>
            Pipe_Output : Pipe_Processor (Process'Access, Standard_Output);
            Pipe_Error  : Pipe_Processor (Process'Access, Standard_Error);
         when False =>
            null;
      end case;
   end record;

   function In_Own_Group (Object : Process) return Boolean is
     (Object.Group_Kind = Same_As_PID);

end Spoon;
