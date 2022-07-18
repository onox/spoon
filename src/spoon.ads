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

package Spoon is
   pragma Preelaborate;

   type Argument (<>) is limited private;

   function To_Argument (Value : String) return Argument
     with Pre => Value'Length > 0;

   type Argument_Access is access all Argument
     with Size => Standard'Address_Size;

   type Argument_Array is array (Positive range <>) of not null Argument_Access;

   ----------------------------------------------------------------------------

   type Result_State is (Error, Exited, Crashed, Terminated);

   type Exit_Status is new Integer;

   Success : constant Exit_Status;

   type Result (State : Result_State) is record
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

   type Program_Kind is (File_Path, Name);

   type IDs_Kind is (Inherit, Real);

   type Process_Group_Kind is (Inherit, Process_ID, Custom);

   type Attributes
     (IDs   : IDs_Kind           := Inherit;
      Group : Process_Group_Kind := Inherit) is
   record
      case Group is
         when Custom => Group_ID : Positive;
         when others => null;
      end case;
   end record;

   Default_Attributes : constant Attributes;

   function Spawn
     (Executable : String;
      Arguments  : Argument_Array   := (1 .. 0 => null);
      Attributes : Spoon.Attributes := Default_Attributes;
      Kind       : Program_Kind     := File_Path) return Result
   with Pre => Executable'Length > 0;
   --  Spawn a process using the given executable, which is either a path
   --  to a file or the name of the program found using the PATH environment variable

private

   Success : constant Exit_Status := 0;

   Default_Attributes : constant Attributes := (others => <>);

   package L1 renames Ada.Characters.Latin_1;

   type Argument is new String
     with Dynamic_Predicate => Argument (Argument'Last) = L1.NUL;

end Spoon;
