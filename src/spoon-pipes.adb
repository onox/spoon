--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2018 - 2019 Joakim Strandberg <joakim@mequinox.se>
--  Copyright (c) 2021 - 2022 onox <denkpadje@gmail.com>
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

--  Code originally from wayland-ada through AWT.OS in Orka project

with Interfaces.C;

package body Spoon.Pipes is

   subtype Size_Type  is Interfaces.C.unsigned_long;
   subtype SSize_Type is Interfaces.C.long;

   use type SSize_Type;

   package API is

      Flag_Close_On_Exec : constant Interfaces.C.int
        with Import, Convention => C, External_Name => "spoon_o_cloexec";

      type File_Descriptor_Array is array (1 .. 2) of File_Descriptor
        with Convention => C;

      function C_Pipe
        (File_Descriptors : in out File_Descriptor_Array;
         Flags            : Interfaces.C.int) return Integer
      with Import, Convention => C, External_Name => "pipe2";

      function C_Read
        (File_Descriptor : Interfaces.C.int;
         Buffer          : in out Ada.Streams.Stream_Element_Array;
         Count           : Size_Type) return SSize_Type
      with Import, Convention => C, External_Name => "read";

      function C_Write
        (File_Descriptor : Interfaces.C.int;
         Buffer          : Ada.Streams.Stream_Element_Array;
         Count           : Size_Type) return SSize_Type
      with Import, Convention => C, External_Name => "write";

      function C_Close
        (File_Descriptor : Interfaces.C.int) return Interfaces.C.int
      with Import, Convention => C, External_Name => "close";

   end API;

   function Create_Pipe return Pipe is
      File_Descriptors : API.File_Descriptor_Array;
   begin
      if API.C_Pipe (File_Descriptors, API.Flag_Close_On_Exec) = 0 then
         return (Read => File_Descriptors (1), Write => File_Descriptors (2));
      else
         raise Constraint_Error;
      end if;
   end Create_Pipe;

   function Read (Object : Pipe) return Ada.Streams.Stream_Element_Array is
      Content : Ada.Streams.Stream_Element_Array (1 .. 1024);

      Count : constant SSize_Type
        := API.C_Read (Interfaces.C.int (Object.Read), Content, Content'Length);
   begin
      case Count is
         when SSize_Type'First .. -1 =>
            raise Constraint_Error;
         when 0 =>
            return Content (1 .. 0);
         when 1 .. SSize_Type'Last =>
            return Content (1 .. Ada.Streams.Stream_Element_Count (Count));
      end case;
   end Read;

   procedure Write (Object : Pipe; Value : Ada.Streams.Stream_Element_Array) is
      use type Ada.Streams.Stream_Element_Offset;

      Next      : Ada.Streams.Stream_Element_Offset := Value'First;
      Remaining : Ada.Streams.Stream_Element_Offset := Value'Length;
   begin
      loop
         declare
            Bytes : Ada.Streams.Stream_Element_Array renames
              Value (Next .. Value'Last);

            Count : constant SSize_Type := API.C_Write
              (File_Descriptor => Interfaces.C.int (Object.Write),
               Buffer          => Bytes,
               Count           => Bytes'Length);
         begin
            case Count is
               when SSize_Type'First .. -1 | 0 =>
                  raise Constraint_Error;
               when 1 .. SSize_Type'Last =>
                  declare
                     Written_Count : constant Ada.Streams.Stream_Element_Count
                       := Ada.Streams.Stream_Element_Count (Count);
                  begin
                     Next      := Next      + Written_Count;
                     Remaining := Remaining - Written_Count;

                     exit when Remaining = 0;
                  end;
            end case;
         end;
      end loop;
   end Write;

   procedure Close (FD : File_Descriptor) is
      use type Interfaces.C.int;

      Result : constant Interfaces.C.int := API.C_Close (Interfaces.C.int (FD));
   begin
      if Result /= 0 then
         raise Constraint_Error;
      end if;
   end Close;

end Spoon.Pipes;
