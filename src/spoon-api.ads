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
with System.Storage_Elements;

private package Spoon.API is
   pragma Preelaborate;

   package SE renames System.Storage_Elements;

   File_Actions_Type_Size : constant Interfaces.C.size_t
     with Import, Convention => C, External_Name => "spoon_posix_spawn_file_actions_t_size";

   Spawn_Attributes_Type_Size : constant Interfaces.C.size_t
     with Import, Convention => C, External_Name => "spoon_posix_spawnattr_t_size";

   type File_Actions_Type     is new SE.Storage_Array
     with Dynamic_Predicate => File_Actions_Type'Length = File_Actions_Type_Size,
          Convention        => C;

   type Spawn_Attributes_Type is new SE.Storage_Array
     with Dynamic_Predicate => Spawn_Attributes_Type'Length = Spawn_Attributes_Type_Size,
          Convention        => C;

   ----------------------------------------------------------------------------

   use Interfaces.C;

   type Error_Code is new int;
   type Process_ID is new int range 1 .. int'Last;
   type Group_ID   is new int range 2 .. int'Last;

   type Argument_C_Array is array (Natural range <>) of aliased Argument_Access
     with Convention => C;

   type Environment_Pointer (<>) is limited private;

   Environment : constant Environment_Pointer
     with Import, Convention => C, External_Name => "environ";

   function Spawn
     (Child_PID    : out Process_ID;
      File_Path    : Argument_Access;
      File_Actions : File_Actions_Type;
      Attributes   : Spawn_Attributes_Type;
      Arguments    : Argument_C_Array;
      Environment  : Environment_Pointer) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawn";

   function Spawnp
     (Child_PID    : out Process_ID;
      File_Name    : Argument_Access;
      File_Actions : File_Actions_Type;
      Attributes   : Spawn_Attributes_Type;
      Arguments    : Argument_C_Array;
      Environment  : Environment_Pointer) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawnp";

   ----------------------------------------------------------------------------

   type Exit_Condition is (Unknown, Exited, Crashed, Terminated);

   function Waitpid
     (Child_PID   : Process_ID;
      Wait_Status : out int;
      Options     : int) return Error_Code
   with Import, Convention => C, External_Name => "waitpid";

   function Waitpid_Status
     (Wait_Status : int;
      Exit_Status : out int) return Exit_Condition
   with Import, Convention => C, External_Name => "spoon_waitpid_status";

   ----------------------------------------------------------------------------

   type Signal is new int range 1 .. int'Last;

   Signal_Kill      : constant Signal := 9;
   Signal_Terminate : constant Signal := 15;
   --  Numbering is always the same on all major platforms (see man page signal(7))

   function Kill_Process
     (Process_ID : API.Process_ID;
      Signal     : API.Signal) return Error_Code
   with Import, Convention => C, External_Name => "kill";

   function Kill_Group
     (Group_ID : API.Group_ID;
      Signal   : API.Signal) return Error_Code
   with Import, Convention => C, External_Name => "killpg";

   ----------------------------------------------------------------------------

   type Attribute_Flags is record
      Reset_IDs           : Boolean := False;
      Process_Group       : Boolean := False;
      Signal_Default      : Boolean := False;
      Signal_Mask         : Boolean := False;
      Scheduler_Parameter : Boolean := False;
      Scheduler_Policy    : Boolean := False;
      Unused              : Boolean := False;
   end record
     with Convention => C_Pass_By_Copy;

   function Attributes_Init (Object : in out Spawn_Attributes_Type) return Error_Code
     with Import, Convention => C, External_Name => "posix_spawnattr_init";

   function Attributes_Destroy (Object : in out Spawn_Attributes_Type) return Error_Code
     with Import, Convention => C, External_Name => "posix_spawnattr_destroy";

--   type Signal_Set            is private;
--
--   function Attributes_Set_Signal_Default
--     (Object  : in out Spawn_Attributes_Type;
--      Signals : access constant Signal_Set) return Error_Code
--   with Import, Convention => C, External_Name => "posix_spawnattr_setsigdefault";
--
--   function Attributes_Set_Signal_Mask
--     (Object : in out Spawn_Attributes_Type;
--      Mask   : access constant Signal_Set) return Error_Code
--   with Import, Convention => C, External_Name => "posix_spawnattr_setsigmask";

   function Attributes_Set_Flags
     (Object : in out Spawn_Attributes_Type;
      Flags  : Attribute_Flags) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawnattr_setflags";

   function Attributes_Set_Process_Group
     (Object   : in out Spawn_Attributes_Type;
      Group_ID : int) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawnattr_setpgroup";

--   function Attributes_Set_Scheduler_Policy
--     (Object : in out Spawn_Attributes_Type;
--      Policy : int) return Error_Code
--   with Import, Convention => C, External_Name => "posix_spawnattr_setschedpolicy";
--
--   function Attributes_Set_Scheduler_Parameter
--     (Object : in out Spawn_Attributes_Type;
--      Param  : access constant sched_param) return Error_Code
--   with Import, Convention => C, External_Name => "posix_spawnattr_setschedparam";

   ----------------------------------------------------------------------------

   function File_Actions_Init (Object : in out File_Actions_Type) return Error_Code
     with Import, Convention => C, External_Name => "posix_spawn_file_actions_init";

   function File_Actions_Destroy (Object : in out File_Actions_Type) return Error_Code
     with Import, Convention => C, External_Name => "posix_spawn_file_actions_destroy";

   subtype Open_Flag is int;
   subtype Mode_Type is unsigned;

   function File_Actions_Add_Open
     (Object : in out File_Actions_Type;
      FD     : File_Descriptor;
      Path   : Argument_Access;
      Flag   : Open_Flag;
      Mode   : Mode_Type) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawn_file_actions_addopen";

   function File_Actions_Add_Close
     (Object : in out File_Actions_Type;
      FD     : File_Descriptor) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawn_file_actions_addclose";

   function File_Actions_Add_Dup2
     (Object     : in out File_Actions_Type;
      FD, New_FD : File_Descriptor) return Error_Code
   with Import, Convention => C, External_Name => "posix_spawn_file_actions_adddup2";

private

   type Environment_Pointer is new System.Address;

--   Signal_Set_Size : constant Interfaces.C.size_t
--     with Import, Convention => C, External_Name => "spoon_sigset_t_size";
--
--   type Signal_Set is record
--      Value : aliased SE.Storage_Array (1 .. SE.Storage_Offset (Signal_Set_Size));
--   end record
--     with Convention => C_Pass_By_Copy;

   ----------------------------------------------------------------------------

   for Exit_Condition use (Unknown => -1, Exited => 0, Crashed => 1, Terminated => 2);
   for Exit_Condition'Size use int'Size;

   for Attribute_Flags use record
      Reset_IDs           at 0 range 0 .. 0;
      Process_Group       at 0 range 1 .. 1;
      Signal_Default      at 0 range 2 .. 2;
      Signal_Mask         at 0 range 3 .. 3;
      Scheduler_Parameter at 0 range 4 .. 4;
      Scheduler_Policy    at 0 range 5 .. 5;
      Unused              at 0 range 6 .. 15;
   end record;
   for Attribute_Flags'Size use short'Size;

end Spoon.API;
