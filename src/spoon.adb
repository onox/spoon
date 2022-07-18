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

package body Spoon is

   function To_Argument (Value : String) return Argument is (Argument (Value & L1.NUL));

   function Wait_For_Exit (PID : API.Process_ID) return Result is
      Wait_Status, Exit_Status : Interfaces.C.int;

      use all type API.Exit_Condition;
      use type API.Error_Code;
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
      Attributes : Spoon.Attributes := Default_Attributes;
      Kind       : Program_Kind     := File_Path) return Result
   is
      PID   : API.Process_ID;
      Error : API.Error_Code;

      use type API.Error_Code;

      Actions : API.File_Actions_Type
        (1 .. API.SE.Storage_Offset (API.File_Actions_Type_Size));
      Attribs : API.Spawn_Attributes_Type
        (1 .. API.SE.Storage_Offset (API.Spawn_Attributes_Type_Size));

      Arg_0 : aliased Argument := To_Argument (Executable);

      Args : API.Argument_C_Array (0 .. Arguments'Length + 1) :=
        (0 => Arg_0'Unchecked_Access, others => null);
   begin
      for Index in Arguments'Range loop
         Args (Index) := Arguments (Index);
      end loop;

      Error := API.File_Actions_Init (Actions);
      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      Error := API.Attributes_Init (Attribs);
      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      if Attributes.Group /= Inherit then
         Error := API.Attributes_Set_Process_Group (Attribs,
           (case Attributes.Group is
              when Process_ID => 0,
              when Custom     => API.Group_ID (Attributes.Group_ID),
              when Inherit    => 0));  --  Cannot be reached
         if Error /= 0 then
            return (State => Spoon.Error, Error_Code => Integer (Error));
         end if;
      end if;

      Error := API.Attributes_Set_Flags (Attribs,
        (Reset_IDs     => Attributes.IDs /= Inherit,
         Process_Group => Attributes.Group /= Inherit,
         others        => False));
      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      case Kind is
         when File_Path =>
            Error := API.Spawn (PID, Args (Args'First), Actions, Attribs, Args, API.Environment);
         when Name =>
            Error := API.Spawnp (PID, Args (Args'First), Actions, Attribs, Args, API.Environment);
      end case;

      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      Error := API.File_Actions_Destroy (Actions);
      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      Error := API.Attributes_Destroy (Attribs);
      if Error /= 0 then
         return (State => Spoon.Error, Error_Code => Integer (Error));
      end if;

      return Wait_For_Exit (PID);
   end Spawn;

end Spoon;
