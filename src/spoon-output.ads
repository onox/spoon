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

with Ada.Strings.Unbounded;

package Spoon.Output is
   pragma Preelaborate;

   package SU renames Ada.Strings.Unbounded;

   function "+" (Value : SU.Unbounded_String) return String renames SU.To_String;

   type Unbounded_String_Array is array (Output_Kind) of SU.Unbounded_String;

   protected type Text_Capturer is new Output_Capturer with
      overriding
      procedure Write
        (Value : Ada.Streams.Stream_Element_Array;
         Kind  : Output_Kind);

      function Get (Kind : Output_Kind) return SU.Unbounded_String;
   private
      Text : Unbounded_String_Array;
   end Text_Capturer;

end Spoon.Output;
